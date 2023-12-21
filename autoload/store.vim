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

function store#show(target, hlname) abort
  let name = a:target
  let pos = s:v_mark_getpos(name)
  let [lnum, col] = empty(pos) ? getcurpos('.')[1:2] : pos
  let text = store#get(name)
  let hl = a:hlname
  call s:v_mark_put(lnum, col, { 'name': name, 'text': text, 'hl': hl })
endfunction

function store#hide(target = '') abort
  call s:v_mark_clear(a:target)
endfunction

function store#getpos(target) abort
  return s:v_mark_getpos(a:target)
endfunction

" 以下、virtual markの互換API

" namespaceのキーまたはproptypeにファイルパスを使い、
" 名前が他のプラグインとぶつかるのを防ぐ
let s:file_name = expand('%:p')
function s:v_mark_name(name) abort
  return s:v_mark_getpos(a:target)
endfunction
let s:default_hl = 'Normal'

if has('nvim')
  let s:ns_dict = {}

  function s:v_mark_clear(name = '') abort
    if a:name ==# ''
      call nvim_buf_clear_namespace(0, -1, 0, -1)
      let s:ns_dict = {}
    elseif has_key(s:ns_dict, a:name)
      call nvim_buf_clear_namespace(0, s:ns_dict[a:name], 0, -1)
      call remove(s:ns_dict, a:name)
    endif
  endfunction

  function s:v_mark_getpos(name) abort
    if has_key(s:ns_dict, a:name)
      let extmarks = nvim_buf_get_extmarks(0, s:ns_dict[a:name], 0, -1, {'limit':1})
      " extmarks = [ [extmark_id, row, col], ... ]
      if !empty(extmarks) && len(extmarks[0]) == 3
        return [extmarks[0][1]+1, extmarks[0][2]+1]
      endif
    endif
    return []
  endfunction

  function s:v_mark_put(lnum, col, opts = {}) abort
    let hl = get(a:opts, 'hl', '')->empty() ? s:default_hl : a:opts.hl
    let text = get(a:opts, 'text', '')
    let name = get(a:opts, 'name', s:file_name)

    call s:v_mark_clear(name)
    let ns_id = nvim_create_namespace(name)
    let s:ns_dict[name] = ns_id

    " nvim_buf_set_extmarkは0-basedなので、1を引く
    call nvim_buf_set_extmark(0, ns_id, a:lnum - 1, a:col - 1, {
          \   'virt_text': [[text, hl]],
          \   'virt_text_pos': 'inline',
          \ })
          " \   'right_gravity': v:false
  endfunction
else
  let s:prop_types = {}

  function s:v_mark_clear(name = '') abort
    if a:name ==# ''
      for k in s:prop_types->keys()
        call s:v_mark_clear(k)
      endfor
    elseif has_key(s:prop_types, a:name)
      call prop_remove({'type': a:name, 'all': v:true})
    endif
  endfunction

  function s:v_mark_getpos(name) abort
    if prop_type_get(a:name)->empty()
      return []
    endif
    let prop = prop_find({'type': a:name, 'lnum': 1})
    return empty(prop) ? [] : [prop.lnum, prop.col]
  endfunction

  function s:v_mark_put(lnum, col, opts = {}) abort
    let hl = get(a:opts, 'hl', '')->empty() ? s:default_hl : a:opts.hl
    let text = get(a:opts, 'text', '')
    let name = get(a:opts, 'name', s:file_name)

    let opts = {'highlight': hl}
    " let opts = {'highlight': hl, 'start_incl':1, 'end_incl':1}
    if get(s:prop_types, name, {}) != opts
      if prop_type_get(name)->empty()
        call prop_type_add(name, opts)
      else
        call prop_type_change(name, opts)
      endif
      let s:prop_types[name] = opts
    endif
    call s:v_mark_clear(name)

    call prop_add(a:lnum, a:col, { 'type': name, 'text': text })
  endfunction
endif
