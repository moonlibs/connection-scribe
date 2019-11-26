package = 'connection-scribe'
version = 'scm-1'

source  = {
    url    = 'git://github.com/moonlibs/connection-scribe.git';
    branch = 'master';
}

description = {
    summary  = "Scribe connector";
    detailed = "Scribe connector";
    homepage = 'https://github.com/moonlibs/connection-scribe.git';
    license  = 'Artistic';
    maintainer = "Mons Anderson <mons@cpan.org>";
}

dependencies = {
    'lua >= 5.1';
    'bin >= scm-3';
    'connection >= 0';
}

build = {
    type = 'builtin',
    modules = {
        ['connection.scribe'] = 'connection/scribe.lua';
    }
}