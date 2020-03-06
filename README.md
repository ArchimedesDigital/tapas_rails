tapas_rails
===========
[![Build Status](https://travis-ci.org/NEU-DSG/tapas_rails.svg?branch=master)](https://travis-ci.org/NEU-DSG/tapas_rails)

Hydra Head for the TAPAS webapp.

## Hungry for more TAPAS?
[TAPAS website](http://www.tapasproject.org/)

[TAPAS public documents, documentation, and meeting notes on GitHub](https://github.com/NEU-DSG/tapas-docs)

[TAPAS webapp (Drupal) on GitHub](https://github.com/NEU-DSG/tapas)

[TAPAS Hydra Head on GitHub](https://github.com/NEU-DSG/tapas_rails)

[TAPAS virtual machine provisioning on GitHub](https://github.com/NEU-DSG/plattr)


## Development


Getting started with local development notes:

* installing nokogiri on OSX: `$ gem install nokogiri -- --with-xml2-include=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/libxml2 --use-system-libraries`
* configuring bundle install with correct openssl from brew:
```
$ bundle config --global build.mysql2 --with-opt-dir="$(brew --prefix openssl)"
$ bundle install
```
* if running with MAMP: `gem install mysql2 -- --with-mysql-config=/Applications/MAMP/Library/bin/mysql_config`
