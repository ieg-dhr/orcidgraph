# Orcidgraph

The open registration for the unique identification of scientific and other academic authors provided by the [ORCID organization](https://orcid.org) contains a large amount of structured data on these authors and – depending on the completeness of the data set – also on their institutional affiliation. However, it is not possible to directly read out corresponding (simultaneous or delayed) links between authors via their affiliations. Orcidgraph offers a solution for this. The open provided ORCID dataset [(ORCID Public Data File)](https://support.orcid.org/hc/en-us/articles/360006897394-How-do-I-get-the-public-data-file-) is exported to Neo4j, where, in addition to corresponding queries in Cypher, the visual options of the Neo4j browser for a clear representation of the connection between the entities Person and Affiliation are enabled.

## Requirements

You will need: 
* a [recent version of ruby](https://www.ruby-lang.org/en/downloads/branches/) including a couple of gems (nokogiri, pry, httpclient, geocoder)
* [Docker](https://www.docker.com/)
* the [ORCID Public Data File](https://support.orcid.org/hc/en-us/articles/360006897394-How-do-I-get-the-public-data-file-) (about 11 GB)  
    **Note:** The ORCID files are generated in October each year and are not updated
until the next year. This explains why some of the ORCID IDs you are looking for
aren’t found. ORCID publishes this file under a [Creative Commons CC0 1.0 Universal Public Domain Dedication](https://creativecommons.org/publicdomain/zero/1.0/).

## Setup

A directory setup like this is recommended:

~~~
orcidgraph
- cache
- src
~~~

Place the data file in the orcidgraph/cache directory.

The file is compressed as a *tar.gz*. For the further progress a format that allows accessing single files without extracting the entire archive is needed – *zip* works for this purpose. The conversion takes quite some time and it involves extracting the *tar.gz* which is then about 210 GB in size. So a little patience is required here and make sure you don't run out of disk space. ;)

~~~bash
cd orcidgraph/cache
tar -xzf ORCID_2019_summaries.tar.gz
zip -r ORCID_2019_summaries.zip summaries
~~~

Check out the git repository:

~~~bash
cd orcidgraph
git clone https://github.com/ieg-dhr/orcidgraph.git src
~~~

Now edit the file `orcidgraph/src/retrieve.rb` configuring the settings in the
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
representation with your ORCID IDs.

If you want to start over, just stop neo4j, remove the neo_data directory and
start it again. This way, the script has an empty neo4j database to work with.
