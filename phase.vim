let s:phase = { 'current': '', 'previous': '', 'reason': '' }

" function phase#full_get() abort
"   return s:phase
" endfunction

" function phase#get() abort
"   return s:phase.current
" endfunction

function phase#is(name) abort
  return s:phase.current ==# a:name
endfunction

function phase#was(name) abort
  return s:phase.previous ==# a:name
endfunction

function phase#set(name, reason = '') abort
  let s:phase.previous = s:phase.current
  let s:phase.current = a:name
  let s:phase.reason = a:reason
endfunction

function phase#forget() abort
  let s:phase.previous = ''
  let s:phase.reason = ''
endfunction
