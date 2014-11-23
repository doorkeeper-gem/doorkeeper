# Contributing

We love pull requests. Here's a quick guide.

Fork, then clone the repo:

    git clone git@github.com:your-username/doorkeeper.git

Set up Ruby dependencies via Bundler

    bundle install

Make sure the tests pass:

    rake

Make your change. Add tests for your change. Make the tests pass:

    rake

Push to your fork and submit a pull request.

At this point you're waiting on us. We like to at least comment on pull requests
within three business days (and, typically, one business day). We may suggest
some changes or improvements or alternatives.

Some things that will increase the chance that your pull request is accepted:

* Write tests.
* Follow our [style guide][style]. Address Hound CI comments unless you have a
  good reason not to.
* Write a [good commit message][commit].

[style]: https://github.com/thoughtbot/guides/tree/master/style
[commit]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
