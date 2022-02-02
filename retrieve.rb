#!/usr/bin/env ruby

# The location of the orcid.org public data file (zip format)
ORCID_PUBLIC_DATA_FILE='../cache/ORCID_2019_summaries.zip'

# Alternatively, configure the path to the extracted ORCID summaries directory
ORCID_PUBLIC_DATA_DIR='../cache/ORCID_2020_10_summaries'

# File for the geo cache (empty json file will be created if it doesn't exist)
GEO_CACHE='../cache/geo_cache.json'

# File for the orcid cache (empty json file will be created if it doesn't exist)
ORCID_CACHE='../cache/orcid_cache.json'

# Json file with matches for organizations
# format: `{"old_name": "new_name", ..}` where the old_name refers to the name
# found in the orcid.org data file and new_name is the name you'd like to use
# for the export
ORG_MATCHES='./org_matches.json'

# The list of orcids you want to extract (one orcid id per line). This is where
# you add the orcid ids you are interested in
ORCID_LIST='./ORCIDs.csv'

# Google location api key (optional). The Combinator below has a function to 
# location match the organzations found in the orgcid.org data file. We had
# hoped to be able to match different organization labels in this way. This
# turned out not to be practical but perhaps you still have use for the code.
GOOGLE_API_KEY=''


require 'tempfile'
require 'csv'

require 'nokogiri'
require 'httpclient'
require 'geocoder'

require 'pry'

class Combinator
  def initialize(data_file)
    @data_file = data_file
    @cache = load_json(GEO_CACHE)
    @orcid_cache = load_json(ORCID_CACHE)
    @org_matches = load_json(ORG_MATCHES)
    @orgs = []

    if GOOGLE_API_KEY != ''
      Geocoder.configure(
        lookup: :google,
        api_key: GOOGLE_API_KEY,
        cache: @cache
      )
    end
  end

  def run
    #distances
    warmup_matching
    import_to_neo
  end

  def warmup_matching
    people.each do |person|
      person['employments'].each do |e|
        org = e['organization']
        org['name'] = @org_matches[org['name']] || org['name']
        if org['org_id'] == ''
          org['org_id'] = Digest::SHA1.hexdigest(org['name'])
        end

        unless org_by_name(org['name'])
          @orgs << org
        end
      end
    end
  end

  def normalized_name(name)
    @org_matches[name] || name
  end

  def org_by_name(name)
    @orgs.find do |o|
      o['name'] == name
    end
  end

  def dinstances
    orgs = []
    distances = []

    people.each do |person|
      person['employments'].each do |e|
        name = e['organization']['name']
        geo = Geocoder.search(name).first

        unless geo
          p e['organization']
          puts 'NO GEO INFO'
          next
        end

        orgs.each do |other_org|
          other_name = other_org['name']
          other_geo = Geocoder.search(other_name).first

          distance = Geocoder::Calculations.distance_between(
            [geo.latitude, geo.longitude],
            [other_geo.latitude, other_geo.longitude],
            units: :km
          )

          if distance < 3
            p e['organization']
            p other_org
            puts "DISTANCE: #{distance}"
            puts '-' * 80
          end
        end

        orgs << e['organization']
      end
    end
  end

  def normalize_orgs(data)
    data['employments'].each do |e|
      e['organization'] = org_by_name(normalized_name(e['organization']['name']))
    end
  end

  def import_to_neo
    orcids.each do |orcid|
      doc = doc_for(orcid)
      if doc
        data = data_for(doc)
        normalize_orgs(data)
        to_neo(data)
      end
    end
  end

  def people
    @people ||= begin
      results = []
      orcids.each do |orcid|
        doc = doc_for(orcid)
        if doc
          results << data_for(doc)
        end
      end
      results
    end
  end

  def org_for(affiliation_group)
    es = affiliation_group.xpath('employment:employment-summary')

    return {
      'name' => es.xpath('common:organization/common:name').text,
      'org_id' => es.xpath('common:organization/common:disambiguated-organization/common:disambiguated-organization-identifier').text
    }
  end

  def orcids
    CSV.read(ORCID_LIST).flatten
  end

  def data_for(doc)
    record = doc.xpath('/record:record')

    return {
      'orcid' => record.xpath('common:orcid-identifier/common:uri').text.split('/').last,
      'first_name' => record.xpath('person:person/person:name/personal-details:given-names').text,
      'last_name' => record.xpath('person:person/person:name/personal-details:family-name').text,
      'employments' => record.xpath('activities:activities-summary/activities:employments/activities:affiliation-group').map{ |ag|
        es = ag.xpath('employment:employment-summary')

        employment = {
          'organization' => {
            'name' => es.xpath('common:organization/common:name').text,
            'org_id' => es.xpath('common:organization/common:disambiguated-organization/common:disambiguated-organization-identifier').text
          },
          'role' => es.xpath('common:role-title').text,
          'start' => to_date(es.xpath('common:start-date')),
          'end' => to_date(es.xpath('common:end-date'))
        }
      }
    }
  end

  def to_date(element)
    result = element.xpath('*').map{|e| e.text}.join('-')
    result == '' ? nil : result
  end

  def doc_for(orcid)
    unless @orcid_cache.keys.include?(orcid)
      @orcid_cache[orcid] = begin
        checksum = orcid[-3..-1]
        file = "#{ORCID_PUBLIC_DATA_DIR}/#{checksum}/#{orcid}.xml"
        if File.exist?(file)
          File.read(file)
        else
          file = "summaries/#{checksum}/#{orcid}.xml"
          result = spawn('unzip', '-p', ORCID_PUBLIC_DATA_FILE, file)
          if result[:status] == 0
            result[:stdout]
          else
            STDERR.puts result[:stderr]
            nil
          end
        end
      end
    end

    if xml = @orcid_cache[orcid]
      Nokogiri::XML(xml)
    end
  end

  def to_neo(data)
    statements = []

    statements << {
      'statement' => '
        MERGE (p:Person {orcid: $person.orcid, first_name: $person.first_name, last_name: $person.last_name})
        RETURN p
      ',
      'parameters' => {
        'person' => {
          'orcid' => data['orcid'],
          'first_name' => data['first_name'],
          'last_name' => data['last_name']
        }
      }
    }

    data['employments'].each do |e|
      statements << {
        'statement' => '
          MERGE (o:Organization {org_id: $org_id, name: $name})
          RETURN o
        ',
        'parameters' => {
          'org_id' => e['organization']['org_id'],
          'name' => e['organization']['name']
        }
      }

      statements << {
        'statement' => '
          MATCH (p:Person {orcid: $orcid}),(o:Organization {org_id: $org_id})
          CREATE (p)-[r:AFFILIATED_WITH]->(o)
          RETURN r
        ',
        'parameters' => {
          'orcid' => data['orcid'],
          'org_id' => e['organization']['org_id']
        }
      }
    end

    request 'POST', 'http://localhost:7474/db/data/transaction/commit', {
      'statements' => statements
    }
  end

  def request(m, url, body = {})
    @client ||= HTTPClient.new

    headers = {'Accept' => 'application/json; charset=utf-8', 'Content-Type' => 'application/json'}
    response = @client.request(m, url, nil, JSON.dump(body), headers)

    if response.status != 200
      binding.pry
    else
      result = JSON.parse(response.body)
      unless result['errors'].empty?
        binding.pry
      end
    end
  end

  def spawn(*cmd)
    r, w = IO.pipe
    re, we = IO.pipe
    pid = Process.spawn(*cmd, out: w, err: we)
    w.close
    we.close

    result = {
      stdout: r.read,
      stderr: re.read
    }
    r.close
    re.close

    Process.waitpid(pid, 0)
    result.merge(
      status: $?.exitstatus
    )
  end

  def load_json(file)
    File.exists?(file) ?
      JSON.parse(File.read file) :
      {}
  end

  def save
    File.open GEO_CACHE, 'w' do |f|
      f.write JSON.dump(@cache)
    end

    File.open ORCID_CACHE, 'w' do |f|
      f.write JSON.dump(@orcid_cache)
    end
  end
end

c = Combinator.new(ORCID_PUBLIC_DATA_FILE)
c.run
c.save
