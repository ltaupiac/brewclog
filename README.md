# brewclog
## Display the last changelog of a Brew Formula

## 💾 Installation

fisher install ltaupiac/brewclog

Demo :

![demo](./demo.png)

### Usage
Usage: brewclog [options] <formula>

Displays the changelog of the latest GitHub release of a Homebrew formula.

Options:

-t, --trace : Verbose mode

-d, --debug : Show debugging information

-h, --help : Show this help message

-v, --version : Show version

### Abbr

An abbr is defined : **,bl**

### Dependencies

- jq    : Command-line JSON processor
- glow  : Render Markdown on the CLI, with pizzazz!
- trurl : URL manipulation

### Limitations
Works only for GitHub

## ©️ License

[MIT](LICENSE)
