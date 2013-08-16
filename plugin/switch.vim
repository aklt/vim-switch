" Script: switch.vim
" Version: 0.1
" Description: switch between related files easily
" Author: anders@bladre.dk

if &cp || exists("g:loaded_switch")
    finish
endif

let g:loaded_switch = "v0.1"
let s:keepcpo            = &cpo
set cpo&vim

if !exists("g:switch_open")
    let g:switch_open = "edit"
endif

if !exists("g:switch_rules")
    let g:switch_rules = {}
endif

if !exists("g:switch_mapping")
    let g:switch_mapping = ',s'
endif

exe "nmap " . g:switch_mapping . " :Switch<CR>"
exe "imap " . g:switch_mapping . " <c-o>:Switch<CR>"
unlet g:switch_mapping

let s:switch_builtin_rules = {
    \  'vim': [
    \    {
    \       'match': '\/plugin\/',
    \       'rhs': [
    \         '\/plugin\/', '\/doc\/', '',
    \         '\.vim$', '.txt', ''
    \       ]
    \    }
    \  ],
    \  'help': [
    \    {
    \       'match': '\/doc\/',
    \       'rhs': [
    \         '\/doc\/', '\/plugin\/', '',
    \         '\.txt$', '.vim', ''
    \       ]
    \    }
    \  ],
    \ 'javascript': [
    \    {
    \      'match': '\/lib\/',
    \      'lhs': '^\(.*\)\/lib\/.*$',
    \      'rhs': [
    \        '^.*\/lib\/\(.*\)$', '\1', '',
    \        '/', '_', 'g',
    \        '\.\([a-z]\+\)$', '-test.\1', '',
    \        '^', 'test/', ''
    \      ]
    \    },
    \    {
    \      'match': '\/test\/',
    \      'lhs': '^\(.*\)\/test\/.*$',
    \      'rhs': [
    \        '^.*\/test\/\(.*\)$', '\1', '',
    \        '_', '/', 'g',
    \        '-test\.\(.*\)$', '.\1', '',
    \        '^', 'lib/', ''
    \      ]
    \    }
    \ ],
    \ 'p': [
    \    {
    \       'parent': 'package.json'
    \    }
    \ ],
    \ 'm': [
    \    {
    \       'parent': '[Mm]akefile'
    \    }
    \ ],
    \ 'r': [
    \    {
    \        'parent': '[Re][Ee][Aa][Dd][Mm][Ee]*'
    \    }
    \ ]
    \ }

let s:switch_builtin_rules['coffee'] = s:switch_builtin_rules['javascript']

fun! <SID>RunSubstitutes(str, substitutes)
    let s = a:substitutes
    let str = a:str
    let index = 0
    while index < len(s)
        let str = substitute(str, s[index], s[index + 1], s[index + 2])
        let index = index + 3
    endwhile
    return str
endfun

fun! <SID>RunRegexOrSubstitutes(str, rxOrSubst)
    if type(a:rxOrSubst) == type([])
        return <SID>RunSubstitutes(a:str, a:rxOrSubst)
    else
        return substitute(a:str, a:rxOrSubst, '\1', '')
    endif
endfun

fun! <SID>GetNewPathName(startDir, lhs, rhs)
    let lhs = <SID>RunRegexOrSubstitutes(a:startDir, a:lhs)
    let rhs = <SID>RunRegexOrSubstitutes(a:startDir, a:rhs)
    return lhs . '/' . rhs
endfun

fun! <SID>GlobParentDir(dirName, startDir)
    let dir = a:startDir
    while len(dir) > 0
        let target = dir . '/' . a:dirName
        let globbed = glob(target, 0, 1)
        if len(globbed) == 1
            return globbed[0]
        endif
        let dir = substitute(dir, "/[^/]*$", "", "")
    endwhile
endfun

fun! <SID>ExecuteMatcher(matcherName, path)
    if has_key(g:switch_rules, a:matcherName)
        let matchers = g:switch_rules[a:matcherName]
    elseif has_key(s:switch_builtin_rules, a:matcherName)
        let matchers = s:switch_builtin_rules[a:matcherName]
    else
        echomsg 'switch.vim: No rule for type ' . a:matcherName
        return 0
    endif
    let target = a:path
    for matcher in matchers
        if has_key(matcher, 'match')
            if match(target, matcher['match']) < 0
                continue
            endif
        endif
        if has_key(matcher, 'parent')
            let target = <SID>GlobParentDir(matcher['parent'], target)
        endif
        if has_key(matcher, 'lhs') && has_key(matcher, 'rhs')
            let target = <SID>GetNewPathName(target,
                            \  matcher['lhs'], matcher['rhs'])
            continue
        endif
        if has_key(matcher, 'lhs')
            let target =
                  \ <SID>RunRegexOrSubstitutes(target, matcher['lhs'])
            continue
        endif
        if has_key(matcher, 'rhs')
            let target =
                  \ <SID>RunRegexOrSubstitutes(target, matcher['rhs'])
        endif
    endfor
    return target
endfun

fun! <SID>Switch(ft)
    let ft = a:ft
    if len(ft) == 0
        let ft = &ft
    endif
    let newDir = <SID>ExecuteMatcher(ft, expand('%:p'))
    if type(newDir) == type('') && len(newDir)
        exe ':' . g:switch_open . " " . newDir
    endif
endfun

command! -nargs=* Switch call <SID>Switch(<q-args>)

let &cpo= s:keepcpo
unlet s:keepcpo
