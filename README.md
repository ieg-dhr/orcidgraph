# Orcidgraph

... description here ..

## Requirements

You will also need a
[recent version of ruby](https://www.ruby-lang.org/en/downloads/branches/)
including a couple of gems (nokogiri, pry, httpclient, geocoder). as
well as [docker](https://www.docker.com/). You also need to get the
[orcid.org public data file](https://support.orcid.org/hc/en-us/articles/360006897394-How-do-I-get-the-public-data-file-).

Note: The orcid.org files are generated in October each year and are not updated
until the next year. This explains why some of the ORCID ids you are looking for
aren't found.

## Setup

I recommend a directory setup like this

~~~
orcidgraph
- cache
- src
~~~

Place the data file in the orcidgraph/cache directory.

The file is compressed as
a tar.gz. We need a format that allows accessing single files without extracting
the entire archive. Zip works for this purpose. The conversion takes quite some
time and it involves extracting the tar.gz which is then about 210G in size.
Make sure you don't run out of disk space ;)

~~~bash
cd orcidgraph/cache
tar -xzf ORCID_2019_summaries.tar.gz
zip -r archives ORCID_2019_summaries.zip
~~~

Check out the git repository:

~~~bash
cd orcidgraph
git checkout https://github.com/ieg-dhr/orcidgraph src
~~~

Now edit the file `orgcidgraph/src/retrieve.rb` configuring the settings in the
top of the file. The file has comments on the various options.

Start the neo4j docker container with

~~~
cd orcidgraph/src
sh neo.sh # ctrl-c to stop the server
~~~

Neo4j should now be available at http://127.0.0.1:7474. There is no username or
password, just hit the login button. The db creates a data directory at
`orcidgraph/cache/neo_data`. Modify `neo.sh` to change this path.

With the db up and running, run the actual script:

~~~
cd orcidgraph/src
ruby retrieve.rb
~~~

When its done, a query like `MATCH (n) RETURN n` should show a graph
representation with your ORCID ids.

If you want to start over, just stop neo4j, remove the neo_data directory and
start it again. This way, the script has an empty neo4j database to work with.