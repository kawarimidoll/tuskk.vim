let s:store = { 'hanpa': '', 'choku': '', 'machi': '', 'okuri': '', 'kouho': '' }

function store#set(target, str) abort
  let s:store[a:target] = a:str
endfunction

function store#get(target) abort
  return s:store[a:target]
endfunction

function store#clear(target = '') abort
  if a:target !=# ''
    call store#set(a:target, '')
    return
  endif
  for t in keys(s:store)
    call store#set(t, '')
  endfor
endfunction

function store#push(target, str) abort
  call store#set(a:target, store#get(a:target) .. a:str)
endfunction

function store#pop(target) abort
  let char = store#get(a:target)->tuskk#utils#lastchar()
  call store#set(a:target, store#get(a:target)->substitute('.$', '', ''))
  return char
endfunction

function store#unshift(target, str) abort
  call store#set(a:target, a:str .. store#get(a:target))
endfunction

function store#shift(target) abort
  let char = store#get(a:target)->tuskk#utils#firstchar()
  call store#set(a:target, store#get(a:target)->substitute('^.', '', ''))
  return char
endfunction

function store#is_blank(target) abort
  return store#get(a:target) ==# ''
endfunction

function store#is_present(target) abort
  return !store#is_blank(a:target)
endfunction
