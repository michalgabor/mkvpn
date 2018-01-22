#!/usr/bin/python

import os
import sys

def auth_success(username):
    """ Authentication success, simply exiting with no error """
    print "[INFO] OpenVPN Authentication success for " + username
    exit(0)
    

def auth_failure(reason, severity="INFO"):
    """ Authentication failure, rejecting login with a stderr reason """
    print >> sys.stderr, "["+severity+"] OpenVPN Authentication failure : " + reason
    exit(1)
        
        
def auth_pass(username, password):
    if (username==os.environ.get('AUTH_USERNAME') and password==os.environ.get('AUTH_PASSWORD')):
        auth_success(username)
    else:
        auth_failure("Invalid credentials for username "+ username)

if all (k in os.environ for k in ("username","password","AUTH_USERNAME","AUTH_PASSWORD")):
    username = os.environ.get('username') 
    password = os.environ.get('password')   
    auth_pass(username, password)

else:
    auth_failure("Missing one of following environment variables : AUTH_USERNAME, AUTH_PASSWORD")

