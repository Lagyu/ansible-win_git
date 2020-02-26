#!/usr/bin/python
# -*- coding: utf-8 -*-

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# Anatoliy Ivashina <tivrobo@gmail.com>
# Pablo Estigarribia <pablodav@gmail.com>
# Michael Hay <project.hay@gmail.com>
# Yuya Sasaki <sasaki.y@ruri.waseda.jp>


DOCUMENTATION = r'''
---
module: win_git
version_added: "2.0"
short_description: Deploy software (or files) from git checkouts on windows
description:
    - Deploy software (or files) from git checkouts on windows
    - SSH only
notes:
    - git for Windows need to be installed
    - SSH only
    - "Tested with Ansible 2.9.3, git version 2.25.1.windows.1 and AWX 9.2.0."
options: 
  accept_hostkey: 
    default: false
    description: 
      - "add hostkey to known_hosts (before connecting to git)"
    required: false
  branch: 
    default: master
    description: 
      - "branch to update / clone the repo"
    required: false
  dest: 
    description: 
      - "destination folder"
    required: true
  key_file: 
    default: "<not specified>"
    description: 
      - "Specify an optional private key file path to use for the checkout."
    required: false
  recursive: 
    default: "yes"
    description: 
      - "if C(no), repository will be cloned without the --recursive option, skipping sub-modules"
    type: bool
  replace_dest: 
    default: false
    description: 
      - "replace destination folder if exists (recursive!)"
    required: false
  repo: 
    aliases: 
      - name
    description: 
      - "address of the repository"
    required: true
  update: 
    default: false
    description: 
      - "do we want to update the repo (use git pull origin branch)"
    required: false
author:
- Anatoliy Ivashina
- Pablo Estigarribia
- Michael Hay
- Yuya Sasaki
'''

EXAMPLES = r'''
  # git clone cool-thing.
  win_git:
    repo: "git@github.com:lagyu/Ansible-win_git.git"
    dest: "{{ ansible_env.TEMP }}\\Ansible-win_git"
    branch: master
    update: no
    replace_dest: no
    accept_hostkey: yes
    key_file: "C:\\Users\\MyUser\\.ssh\\id_ed25519_1"
'''
