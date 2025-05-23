# Zendesk Apps Support

## Description
Classes to manage and validate Zendesk Apps. This is a gem used in [Zendesk Apps Tools](https://github.com/zendesk/zendesk_apps_tools/).

## Owners
This repo is owned and maintained by the Zendesk Apps team. You can reach us on wattle@zendesk.com. We are located in Melbourne!

## Getting Started
When you want to help **develop** this tool, you will need to clone this repo.

Very likely you want to try out your changes with the use of ZAT. See [ZAT](https://github.com/zendesk/zendesk_apps_tools/) for how to get ZAT/ZAS in development.

## Testing
This project uses Rspec, which can be run with `bundle exec rake`.

## Contribute
* Put up a PR into the master branch.
* CC and get two +1 from @zendesk/wattle.

### Releasing a new version
A new version is published to RubyGems.org every time a change to `version.rb` is pushed to the `main` branch.
In short, follow these steps:
1. Update `version.rb`,
2. run `bundle lock` to update `Gemfile.lock`,
3. merge this change into `main`, and
4. look at [the action](https://github.com/zendesk/zendesk_apps_support/actions/workflows/publish.yml) for output.

To create a pre-release from a non-main branch:
1. change the version in `version.rb` to something like `1.2.0.pre.1` or `2.0.0.beta.2`,
2. push this change to your branch,
3. go to [Actions → “Publish to RubyGems.org” on GitHub](https://github.com/zendesk/zendesk_apps_support/actions/workflows/publish.yml),
4. click the “Run workflow” button,
5. pick your branch from a dropdown.

## Bugs
Bugs can be reported as an issue here on github, or submitted to support@zendesk.com. By mentioning this project it will assigned to the right team.

## Copyright and license
Copyright 2013 Zendesk
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
