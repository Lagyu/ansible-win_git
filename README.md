# ansible-win_git
Git module for Windows.

Added some fixes to [Original version](https://github.com/tivrobo/ansible-win_git).

Working correctly on my Ansible 2.9.3, git version 2.25.1.windows.1 and AWX 9.2.0 environment.

Features:
- Rewrited to use "Ansible.Basic" module to manage with AWX or Ansible Tower.
- Added "key_file" option. (currently only supports local file path)

## Installation:
Copy ***win_git.ps1*** and ***win_git.py*** files to **[default-module-path](http://docs.ansible.com/ansible/latest/reference_appendices/config.html#default-module-path)** directory
## Usage:
```
- name: git clone cool-thing
  win_git:
    repo: "git@github.com:Lagyu/ansible-win_git.git"
    dest: "{{ ansible_env.TEMP }}\\ansible-win_git"
    branch: master
    update: no
    recursive: yes
    replace_dest: no
    accept_hostkey: yes
    key_file: "C:\\Users\\MyUser\\.ssh\\id_ed25519_1"
```
## Output:
```
ok: [windows2008r2.example.com] => {
  "changed": false, 
  "invocation": {
      "module_name": "win_git"
  }, 
  "win_git": {
    "accept_hostkey": true, 
    "changed": true, 
    "dest": "C:\\Users\\MyUser\\AppData\\Local\\Temp\\ansible-win_git", 
    "msg": "Successfully cloned git@github.com:Lagyu/ansible-win_git.git into C:\\Users\\MyUser\\AppData\\Local\\Temp\\ansible-win_git.", 
    "repo": "git@github.com:Lagyu/ansible-win_git.git",
    "output": "", 
    "recursive": true, 
    "replace_dest": false, 
    "return_code": 0,
    "ssh_command": "ssh -o IdentitiesOnly=yes -i \"C:\\Users\\MyUser\\.ssh\\id_ed25519_1\",
    "key_file": "C:\\Users\\MyUser\\.ssh\\id_ed25519_1",
  }
}
```
## TODO:
- [ ] handle correct status change when using update
- [ ] add check/diff mode support
- [ ] check for idempotence
- [ ] add tests
## More info:
- http://docs.ansible.com/ansible/latest/dev_guide/developing_modules_general_windows.html
