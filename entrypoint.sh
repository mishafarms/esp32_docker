#!/usr/bin/env bash
set -e

# Use the USERNAME environment variable
USERNAME=${USERNAME:-esp32_user}  # Fallback to 'esp32_user' if not set

# get uid/gid
USER_UID=`ls -nd /home/$USERNAME | cut -f3 -d' '`
USER_GID=`ls -nd /home/$USERNAME | cut -f4 -d' '`

# get the current uid/gid of myuser
CUR_UID=`getent passwd $USERNAME | cut -f3 -d: || true`
CUR_GID=`getent group $USERNAME | cut -f3 -d: || true`

# if they don't match, adjust
if [ ! -z "$USER_GID" -a "$USER_GID" != "$CUR_GID" ]; then
  groupmod -g ${USER_GID} $USERNAME
fi
if [ ! -z "$USER_UID" -a "$USER_UID" != "$CUR_UID" ]; then
  usermod -u ${USER_UID} $USERNAME
  # fix other permissions
  find / -uid ${CUR_UID} -mount -exec chown ${USER_UID}.${USER_GID} {} \;
fi

#echo "The number of arguments is: $#"
#echo "The args are $1"

if [[ $1 != *eclipse* && -f $IDF_PATH/export.sh ]]; then
#    echo "IDF_PATH = $IDF_PATH"
    . $IDF_PATH/export.sh >/dev/null
    export ESPIDF=$IDF_PATH
fi

#. $IDF_PATH/export.sh
#
#exec "$@"
# drop access to myuser and run cmd

export LC_ALL=C.UTF-8
export NO_AT_BRIDGE=1

if [[ $1 != "sudo" ]]; then
	if [[ -f ~$USERNAME/set_tty_sym.py ]]; then
		~$USERNAME/set_tty_sym.py
	fi
	exec gosu $USERNAME "$@"
else
	shift
	exec "$@"
fi
