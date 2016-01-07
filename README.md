# vaultgrep
ugly little tool to search DCSS vaults

a bit buggy at this point, also needs to be rethought --- currently it does
searches in a "streaming" fashion which means it has order dependencies and
does not handle searching multiple bins for multiple things very well.

```
vaultgrep [-a|--and|-o|--or]
	  [--[no-][feature|monster|item] [--property=tag] [--branch=place]
	  pattern ...
```

Currently assumes you're in a source tree, or otherwise uses a fixed
loccation that is only valid on some (not all) of my machines >.>
