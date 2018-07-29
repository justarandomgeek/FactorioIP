# Clusterio

Clusterio allows factorio mods to communicate outside the game. This is the client side mod. To work, 
it also requires a server side mod located at https://github.com/Danielv123/factorioClusterio . It also 
has the full readme, so head over there. 

Another practical side project is the clusterio client, which is a standalone app that makes it easier to 
connect to clusterio servers. Its still very much WIP at the point of writing and not really recommended.

https://github.com/Danielv123/factorioClusterioClient

## Build Instructions

### Configuration
In `config/buildinfo.json` change the value of `output_directory` to point to the `/mods` folder of the Factorio installation you wish to target.

### Windows Build
In Powershell, run `build.ps1`. This will clean out the old mod folder and copy the necessary files to a new mod folder in your specefied factorio installation. It takes care of giving it the proper version suffix to match the `info.json`.

### Windows Deploy
In Powershell reun `deplpy.ps1 -Tag [Tag Name]`. This will checkout the specified Tag (if it exists) and create a zip package ready to drop into a mods folder. The tag name is identical to the version number built.

Build setup lifted from https://github.com/anythingapplied/WhistleStop
