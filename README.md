# mlabs-tooling.nix (codename echidna)

A flake that provides everything necessary to set up a project within our scopes. This is also a place to come to if you're a library maintainer or have issues with a dependency. 

## Motivation

Within MLabs we have a wide variety of projects that each depend on libraries that often are open source. There has been a decoupling between the downstream users and the library maintainers and between the different downstream users which impose some very serious issues that are endangering the success for certain projects and ultimately MLabs itself. 

### Breaking changes 

Breaking changes must be fixed on a case by case basis, per project. This is not ideal as people are wasting a lot of time duplicating work and depending on which problem they're fixing other people (typically the library maintainers) are more qualified to fix the issue

### Haskellers should write Haskell 

Developers reportedly spend a not negligible amount of time fighting with nix tooling, making a Haskell dev not being able to write Haskell but writing Nix instead spending more time fighting than solving problems. This is neither good for the developers nor for MLabs itself. Ideally we should provide wrappers that are trivial to use and work out of the box for its users.

### Project setup

When setting up projects people are going to the same set of issues which makes them unknowingly duplicate a lot of work. This should be the task of the `plutus-scaffold` but it is out of date and needs a rework to make it easier to use. Ultimately it should be rewritten using tools from this flake to show an example of composing the different tools from this flake so that non-nix people can use it. 

### Synchronisation

Projects tend to be constantly out of sync - to fix this issue we need to tighten the feedback cycle between downstream users and library maintainers and provide a simple way to raise and resolve issues company wide and with a good visibility. Another important step towards syncing dependencies is to try to reduce the dependency set by reducing inputs. 

### Documentation for tooling 

How to use Nix tooling is mainly folklore or even worse specialist knowledge; although we cannot trivially fix the issues with the documentation of haskell.nix, we can try to provide easy to use wrappers that suit our company's needs and are themselves well-documented. 

