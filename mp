#!/usr/bin/env python
""" Launchpad Merge Proposal helper

    Run with Launchpad.net MP url and this will spawn a shell with the working directory
    being the checked out code with the uncommitted merged code. Then run 'bzr di' or tests as needed.
    When you exit the shell you will be prompted to merge and for commit message as needed.

    Assumptions:
    - You have bzr installed and your user is setup with launchpad credentials.

    Resources:
    - https://help.launchpad.net/API/launchpadlib
    - https://launchpad.net/+apidoc/1.0.html
"""
from contextlib import contextmanager
import os
import requests
import shutil
import sys
import subprocess
import tempfile
import urlparse

from launchpadlib.launchpad import Launchpad

BRANCH_CACHE = os.path.expanduser('~/.launchpad_cache')
SHELL = '/bin/bash'


def main(argv=None):
    if argv is None:
        argv = sys.argv
    if len(argv) != 2:
        print('Usage: {} <Merge Proposal url>'.format(argv[0]))
        return 1

    # Auth launchpad
    launchpad = Launchpad.login_with('mp', 'production')

    # Pull the branch details from the api
    branch_name, merge_id = parse_mp_url(argv[1])
    branch = launchpad.branches.getByUniqueName(unique_name=branch_name)
    mps = branch.landing_targets
    mp = None
    for tmp_mp in mps:
        if tmp_mp.web_link == argv[1]:
            mp = tmp_mp
            break

    if mp is None:
        print('Error finding the merge proposal via the API')
        sys.exit(3)

    target_branch = mp.target_branch.bzr_identity
    source_branch = mp.source_branch.bzr_identity

    cached_branch = cache_branch(target_branch)
    # Branch/merge to a tempdir
    with tempdir() as base_dir:
        subprocess.check_call(['bzr', 'branch', cached_branch, base_dir])
        # bzr merge will fail with conflicts, but I don't want to bail so use call not check_call
        subprocess.call(['bzr', 'merge', source_branch], cwd=base_dir)

        # Drop to a shell
        print('The uncommitted merged code is available here, run tests, bzr di, etc as needed.')
        print('When the shell is exited you will be prompted regarding merging')
        subprocess.call([SHELL], cwd=base_dir)

        # Merge or not
        if raw_input('Would you like to merge? [y/n] ') == 'y':
            # Have the user write the merge comment
            lp_login = subprocess.check_output(['bzr', 'launchpad-login']).strip()
            comment_str = '[{}, r={}] {}'.format(mp.registrant_link.split('~')[-1],
                                                 lp_login, mp.description)
            comment_path = comment_file(base_dir, comment_str)

            # Approve in the MP
            mp.createComment(subject='Re: [Merge] {} into {}'.format(source_branch, target_branch),
                             vote='Approve')

            # Merge and push
            subprocess.check_call(['bzr', 'ci', '-F', comment_path], cwd=base_dir)
            subprocess.check_call(['bzr', 'push', target_branch], cwd=base_dir)
        else:
            if raw_input("Would you like to do a 'Needs Fixing' comment on the MP? [y/n] ") == 'y':
                comment_path = comment_file (base_dir, '# Write your comment here (remove this line)')
                with open(comment_path, 'r') as comment:
                    comment = comment.read()

                mp.createComment(subject='Re: [Merge] {} into {}'.format(source_branch, target_branch),
                                 content=comment, vote='Needs Fixing')


def cache_branch(target_branch):
    """ Cache branches locally to avoid so much download.
        The first download will be the full thing, subsequent downloads will just be a bzr pull
        Thanks Paul Gear for this idea.
    """
    if not os.path.exists(BRANCH_CACHE):
        os.mkdir(BRANCH_CACHE)

    target_dir = os.path.join(BRANCH_CACHE, target_branch)
    if os.path.exists(target_dir):
        subprocess.call(['bzr', 'pull'], cwd=target_dir)
    else:
        pdir = os.path.join(BRANCH_CACHE, os.path.dirname(target_branch))
        if not os.path.exists(pdir):
            os.makedirs(pdir)
        subprocess.check_call(['bzr', 'branch', target_branch, target_dir])

    return target_dir


def comment_file(dir, contents):
    """ Create a temporary comment file in dir with prepopulate contents, then allow the user
        to edit it.
        Return the path the final file
    """
    comment_file, comment_path = tempfile.mkstemp(dir=dir)
    os.write(comment_file, contents)
    editor = os.environ.get('EDITOR', 'vi')
    # check_call because if the user aborts here, it should stop the merge/push/comment
    subprocess.check_call([editor, comment_path])
    return comment_path


def parse_mp_url(mp_url):
    """ Parse a merge proposal url and return the branch name and merge id """
    parts = urlparse.urlsplit(mp_url)
    if not parts.netloc.startswith('code.launchpad.net'):
        print('Error parsing url, should be of the form'
              'https://code.launchpad.net/~<author.name>/<project.name>/<branch.name>/+merge/<id>')
        sys.exit(2)

    branch_name, merge_id = parts.path.split('+merge', 1)

    return branch_name.rstrip('/').lstrip('/'), merge_id.strip('/')


@contextmanager
def tempdir():
    """ A simple temp directory context manager. """
    tdir = tempfile.mkdtemp()
    base_dir = os.path.join(tdir, 'mp')
    try:
        yield base_dir
    finally:
        shutil.rmtree(tdir)


if __name__ == "__main__":
    sys.exit(main())
