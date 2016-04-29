#!/usr/bin/python

import argparse
import os
import re
import subprocess
import sys


def get_files_recursive(folder, excludes_regex, extensions_regex, files):
    for name in os.listdir(folder):
        if not excludes_regex.search(name):
            path = os.path.join(folder, name)
            if os.path.isfile(path):
                if extensions_regex.search(name):
                    files.append(path)
            else:
                get_files_recursive(path, excludes_regex, extensions_regex,
                                    files)


def exec_cpplint(files, cpplint, cpplint_args):
    if not files:
        return False

    args = [sys.executable, cpplint,
            '--extensions=c,cc,cpp,cxx,c++,h,hpp,hxx,h++', '--output=eclipse']
    args += cpplint_args

    for f in files:
        args.append(f)

    has_error = False
    process = subprocess.Popen(args, bufsize=4096, close_fds=True,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, )
    for line in iter(process.stdout.readline, ''):
        sys.stdout.write(line)

        if ': warning:' in line:
            has_error = True

    return has_error


def main():
    parser = argparse.ArgumentParser(prog='cpplint-wrapper.py')
    parser.add_argument('--cpplint', default='cpplint.py')
    parser.add_argument('--excludes', default='(CVS|\.git|\.hg|\.svn)')
    parser.add_argument('--extensions',
                        default='\.(c|cc|cpp|cxx|c\+\+|h|hpp|hxx|h\+\+)$')
    parser.add_argument('--filter')
    parser.add_argument('names', nargs='+')
    args = parser.parse_args()

    excludes = args.excludes
    excludes_regex = re.compile(excludes)

    extensions = args.extensions
    extensions_regex = re.compile(extensions)

    files = []
    for name in args.names:
        if os.path.isfile(name):
            if extensions_regex.search(name):
                files.append(name)
        else:
            get_files_recursive(name, excludes_regex, extensions_regex, files)

    cpplint_args = []
    if args.filter:
        cpplint_args += ['--filter={}'.format(args.filter)]

    has_error = exec_cpplint(files, args.cpplint, cpplint_args)

    if has_error:
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == '__main__':
    main()
