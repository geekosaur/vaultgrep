# vaultgrep
ugly little tool to search [DCSS](http://crawl.develz.org) vaults

a bit buggy at this point, also needs to be rethought --- currently it does
searches in a "streaming" fashion which means it has order dependencies and
does not handle searching multiple bins for multiple things very well.

```
vaultgrep [-a|--and|-o|--or]
	  [--[no-][feature|monster|item] [--property=tag] [--branch=place]
	  pattern ...
```

Currently assumes you're in a source tree, or otherwise uses a fixed
location that is only valid on some (not all) of my machines >.>

A recent example (that caused me to dig this back out and clean it up
a bit...): someone was looking for the Ely altar vault with a neutral
quokka. The and/or stuff doesn't mix well with the current "streaming"
design, but there aren't *that* many vaults with neutral quokkas:

```
pyanfar «vaultgrep:master» Z$ vaultgrep --monster neutral quokka        
altar/overflow.des:530: [elyvilon_altar_4] MONS:   patrolling quokka att:good_neutral
```

Note that using this does assume some familiarity with vault syntax.
