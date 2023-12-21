let s:mode_dict = {
      \ 'hira': { 'conv': 'tuskk#converters#as_is' },
      \ 'zen_kata': { 'conv': 'tuskk#converters#hira_to_kata' },
      \ 'han_kata': { 'conv': 'tuskk#converters#hira_to_han_kata' },
      \ 'zen_alnum': { 'conv': 'tuskk#converters#alnum_to_zen_alnum', 'direct': v:true },
      \ 'abbrev': { 'conv': 'tuskk#converters#as_is', 'direct': v:true, 'start_sticky': v:true },
      \ }

function tuskk#mode#name() abort
  return s:current_mode.name
endfunction

function tuskk#mode#is_start_sticky() abort
  return  get(s:current_mode, 'start_sticky', v:false)
endfunction

function tuskk#mode#is_direct() abort
  return get(s:current_mode, 'direct', v:false)
endfunction

function tuskk#mode#convert(str) abort
  return call(s:current_mode.conv, [a:str])
endfunction

function tuskk#mode#clear() abort
  " setを使う場合と異なりechoしない
  let s:current_mode = s:mode_dict.hira
endfunction

function tuskk#mode#get_alt(mode_name) abort
  return (a:mode_name ==# tuskk#mode#name()) ? s:mode_dict.hira : s:mode_dict[a:mode_name]
endfunction

function tuskk#mode#convert_alt(mode_name, str) abort
  let selected_mode = tuskk#mode#get_alt(a:mode_name)
  return call(selected_mode.conv, [a:str])
endfunction

function tuskk#mode#set_alt(mode_name) abort
  let s:current_mode = tuskk#mode#get_alt(a:mode_name)
  echo $'{tuskk#mode#name()} mode'
  return s:current_mode
endfunction

function tuskk#mode#set(mode_name) abort
  let s:current_mode = s:mode_dict[a:mode_name]
  echo $'{tuskk#mode#name()} mode'
  return s:current_mode
endfunction

" initialize dict
for [key, val] in items(s:mode_dict)
  let val.name = key
endfor

call tuskk#mode#clear()
