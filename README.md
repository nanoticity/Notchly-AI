# Notchly AI

## About
I was very annoyed at having to switch windows and have a bunch of apps open just to use AI, so I created this, which makes use of the notch on newer Macs to launch a simple chat interface backed by OpenAI.

## Installation
[Install the app](https://github.com/nanoticity/Notchly-AI/releases/tag/v3) and go to your Downloads folder. From there drag it into your applications folder and it is ready to use!

## Setup
On first launch the app asks for an OpenAI API key (get one at https://platform.openai.com/api-keys). The key is validated against `GET https://api.openai.com/v1/models` and stored locally in `UserDefaults` under `openai_api_key`. Chats use the `gpt-4o-mini` model via the streaming Chat Completions API.