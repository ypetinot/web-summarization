This repository contains the source code for a framework for indicative Web summarization. Although primary intended for nearest-neighbor-based --- i.e. instance-based ---- summarization approaches, it provides the necessary infrastructure for alternate forms of indicative Web summarization, including for the construction of extraction-based summarization systems.

The repository is organized as follows:
--------------------------------------

bin/ => bin directory for all non-summarizer-specific binaries/scripts.

data/ => code supporting all dataset processing operations, including the collection and analysis of ODP data.

evaluation/ => all evaluation-related code.

models/ => root directory for global models derived from ODP data. Only the code under topic-models is currently relevant.

services/ => framework-wide services.

src/ => source directory for all non-summarizer-specific code.

summarizers/ => root directory for individual indicative summarization systems.

third-party/ => root directory for all third-party dependencies.
