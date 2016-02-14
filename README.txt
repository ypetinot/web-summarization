This repository contains the source code for a framework for indicative Web summarization. Although primary intended for nearest-neighbor-based --- i.e. instance-based ---- summarization approach, it also provides the necessary infrastructure for alternate summarization systems (e.g. extraction-based).

The repository is organized as follows:
--------------------------------------

bin/ => bin directory for all non-summarizer-specific binaries/scripts.

data/ => all dataset processing operations, including the collection and analysis of ODP data.

evaluation/ => all evaluation-related code.

models/ => models derived from training data, only the code under topic-models is currently relevant, in particular to \cite{Petinot2011}.

services/ => framework-wide services.

src/ => source directory for all non-summarizer-specific code.

summarizers/ => root directory for individual indicative summarization systems.

third-party/ => root directory for all third-party dependencies.
