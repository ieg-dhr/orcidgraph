# ORCIDgraph

The open registration for the unique identification of scientific and other academic authors provided by the [ORCID organization](https://orcid.org) contains a large amount of structured data on these authors and – depending on the completeness of the data set – also on their institutional affiliations. However, it is not possible to directly read out corresponding (simultaneous or time-delayed) links between authors via their affiliations. Orcidgraph offers a solution for this. The openly available ORCID dataset [(ORCID Public Data File)](https://support.orcid.org/hc/en-us/articles/360006897394-How-do-I-get-the-public-data-file-) is exported to Neo4j, where, in addition to corresponding queries in Cypher, the visual options offered by Neo4j's browser enable a clear representation of the connections between the entities “Person” and “Affiliation”.


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

Place the data file in the `orcidgraph/cache` directory. The file is compressed as a *tar.gz*. To proceed further, you could use a format that allows accessing single files without extracting the entire archive – *zip* works for this purpose. The conversion takes quite some time and it involves extracting the *tar.gz* which is then about 210 GB in size. So a little patience is required here, and make sure you don't run out of disk space. ;)

~~~bash
cd orcidgraph/cache
tar -xzf ORCID_2019_summaries.tar.gz

# optional, the scripts will also work with the summaries folder from the
# step before
zip -r ORCID_2019_summaries.zip summaries
~~~

Check out the git repository:

~~~bash
cd orcidgraph
git clone https://github.com/ieg-dhr/orcidgraph.git src
~~~

Now edit the file `orcidgraph/src/retrieve.rb` and configure the settings at the top of the file. The file has comments on the various options. The path to the required file ORCID_LIST (ORCIDs.csv) is also specified here. You have to create this file, which contains the list of ORCID-IDs you want to be extracted. The path to the file ORG_MATCHES (org_matches.json) is also described here. This is a file in which you can set definitions for your export to map correspondences between one name and another in order to avoid redundancies (a necessary step due to the free-input options in the ORCID registry). For example: 1. IEG -> Leibniz Institute of European History, 2. IEG Mainz -> Leibniz Institute of European History, 3. …).

Start the Neo4j Docker container with:

~~~
cd orcidgraph/src
sh neo.sh
~~~

Neo4j should now be available at http://127.0.0.1:7474. There is no username or
password, just hit the “connect” button. The database creates a data directory at
`orcidgraph/cache/neo_data`. Modify `neo.sh` to change this path.

With the database up and running, run the actual script:

~~~
cd orcidgraph/src
ruby retrieve.rb
~~~

When its done, a query like `MATCH (n) RETURN n` should show a graph
representation with your ORCID IDs.

If you want to start over, just stop Neo4j (# ctrl-c), remove the `neo_data` directory and
start it again. This way, the script has an empty Neo4j database to work with.
