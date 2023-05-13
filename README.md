# jocqey

## Qortal start stop

### Synopsis

The scripts in this repository are used to start and stop the Qortal server.
The idea is to implement extra functionality to the ordinary startStopScripts such as eg. optimization of JAVA memory args.

Ths scripts are ultimately meant to end up in the "qortal" folder of the Qortal server.
But during development they can be kept in a separate folder, and all scripts named "optional_*" are meant to handle
this scenario.

This means that you can clone this repository into a separate folder inside the qortal-folder, and then run the
optional-scripts from there.

If the qortal-folder does not contain a file "jocqey.config", then such a file will be created when 'jocqey' is run.
Then the config-file will used when starting the Qortal server.

Java memory args will be written to the config-file - either commented or uncommented - depending on variables set in
the function 'calculate_jvm' in the file 'jocqey.lib.sh'.

Only uncommented settings in config are used when running the Qortal server.

### Further
The meat of the code is in the file 'jocqey.lib.sh'.
The start/stop scripts merely 'source' this file and call the functions defined in it.

As the original start.sh script from qortal-core was apparently intended to be posix-compliant, I have tried to keep the code posix-compliant. Even though I normally bash.
Curiously, the original stop.sh script was not posix-compliant, so there small remnants of bashisms, even though I have cleansed it somewhat.
It has been a fun exercise to try to keep the code posix-compliant, but if this is not a requirement, then the code could be bashed instead. Which would ease development.
Also the stop-function assumes that 'curl' is available, and that is some assumption.
Scripting could be implemented to evaluate dependencies such as this.

Overall I have mostly maintained the 'original' logic, but if worthwhile, I could see improvements to be made to robustify some things - particularly the stop-function.

### The stuff that I forgot to write about
, maybe because it was too obvious to me.
You're welcome ;-):
...
