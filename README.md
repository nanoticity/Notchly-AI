# Notchly AI

## About
I was very annoyed at having to switch windows and have a bunch of apps open just to use AI, so I created this, which makes use of the notch on newer Macs to launch a simple integration of llama.

## Installation

### Ollama
[Install this app](https://ollama.com) on your Mac and make sure you have at least 7gb of disk space left. Once this is installed drag it into your applications folder and launch it. 

### Terminal
Open terminal (command+space and type terminal and then enter), then type
```zsh
ollama run llama3
```
Now wait for this to install, it takes about 1 to 5 minutes. Once this installed you are ready to get the app running! But first, lets run some checks:

1. Open up your browser and type in http://localhost:11434
2. If it says "Ollama is running" then it worked, if not then repeat the steps above.

### App Installation
Go to the app [releases](https://github.com/nanoticity/Notchly-AI/releases/tag/v1.2) and download the top file. After this drag "Notchly AI.app" to you Applications folder. Launch the app and it should be working. To check, position our mouse near the bottom of the notch and check if it works. Try a couple of prompts too just to make sure. 