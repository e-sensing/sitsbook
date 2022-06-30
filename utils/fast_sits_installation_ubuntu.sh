#!/bin/bash

#
# Add the repository key so that apt knows it (this is optional but recommended)
#
apt install --yes --no-install-recommends wget ca-certificates software-properties-common       # to add the key
wget -q -O- https://eddelbuettel.github.io/r2u/assets/dirk_eddelbuettel_key.asc \
| tee -a /etc/apt/trusted.gpg.d/cranapt_key.asc

#
# Add the repository to the apt registry:
#
echo "deb [arch=amd64] https://dirk.eddelbuettel.com/cranapt focal main" \
> /etc/apt/sources.list.d/cranapt.list

echo "Package: * \nPin: release o=CRAN-Apt Project \nPin: release l=CRAN-Apt Packages \nPin-Priority: 700" \
> /etc/apt/preferences.d/99cranapt
apt update