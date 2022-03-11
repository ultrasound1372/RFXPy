# RFXPy
## What is it?
RFXPy is a python port of RFXGen, a tool known widely in the blind community, which itself is a port of SFXR. RFXGen was the only screen reader accessible SFXR version available to us at the time.

### Why the port?
RFXGen has been abandoned for a long time, was not really open-sourced, and was compiled with a now vastly outdated version of PureBasic.
It also contained some accessibility bugs, namely that some of its sliders didn't work properly or jumped focus randomly.

## About the included PureBasic source code
The files `rf_gen.pb` and `Spotfx2b Include.pbi` make up the original source code of a version of RFXGen given to a friend of its developer. I have permission from that friend and said developer to use this code in the construction of a modern port.  
These files serve as a reference for constructing the port. The include provides the API and code of the synthesis module, and the main file provides the UI.  
These files are not covered by the license of the repository.

## Running the port
To compile and run the port you will need
* Python 3.7 or higher
* Cython 3.0a6 or higher. Available on pip with `--pre` flag
* A c compiler compatible with your version of python, required by cython. For Windows this must be a version of MSVC
* WXPython, for the UI and sound playback code
* The pip modules clipboard and pypubsub

Other than python and the c compiler, these should be easy to install via `python -m pip install -r requirements.txt`  
To build the RFX c extension, run `python setup.py build_ext`  
It is highly encouraged that you use a python virtual environment for this repository. The ignore file makes a provision for the directory env, but other options such as conda and pipenv may be used if desired, though have not been tested.

## Status
The synthesis module is complete and has been extended beyond the base specification of the PureBasic code. The UI, however, has barely begun, due to me not being comfortable with WXPython as of yet.
This is the initial reason for me creating this public repository, so that other contributors may help flesh out the UI and test the synthesis module.