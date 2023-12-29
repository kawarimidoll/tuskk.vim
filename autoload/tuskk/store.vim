let s:store = { 'hanpa': '', 'machi': '', 'okuri': '', 'kouho': '' }

function s:export_set(target, str) abort
  let s:store[a:target] = a:str
endfunction

function s:export_get(target) abort
  return s:store[a:target]
endfunction

function s:export_get_all() abort
  return s:store
endfunction

function s:export_clear(target = '') abort
  if a:target !=# ''
    call s:export_set(a:target, '')
    return
  endif
  for t in keys(s:store)
    call s:export_set(t, '')
  endfor
endfunction

function s:export_push(target, str) abort
  call s:export_set(a:target, s:export_get(a:target) .. a:str)
endfunction

function s:export_pop(target) abort
  let char = s:export_get(a:target)->tuskk#utils#lastchar()
  call s:export_set(a:target, s:export_get(a:target)->substitute('.$', '', ''))
  return char
endfunction

function s:export_unshift(target, str) abort
  call s:export_set(a:target, a:str .. s:export_get(a:target))
endfunction

function s:export_shift(target) abort
  let char = s:export_get(a:target)->tuskk#utils#firstchar()
  call s:export_set(a:target, s:export_get(a:target)->substitute('^.', '', ''))
  return char
endfunction

function s:export_is_blank(target) abort
  return s:export_get(a:target) ==# ''
endfunction

function s:export_is_present(target) abort
  return !s:export_is_blank(a:target)
endfunction

function s:export_show(list) abort
  call s:export_hide()
  let [lnum, col] = getcurpos()[1:2]
  call s:v_mark_put(lnum, col, a:list)
endfunction

" 以下、virtual markの互換API

" namespaceのキーまたはproptypeの名前が他のプラグインとぶつかるのを防ぐ
function s:v_mark_name(name) abort
  return $'tuskk#store#{a:name}'
endfunction

if has('nvim')
  let s:ns_dict = {}

  function s:export_hide() abort
    for v in s:ns_dict->values()
      call nvim_buf_clear_namespace(0, v, 0, -1)
    endfor
    let s:ns_dict = {}
  endfunction

  function s:v_mark_put(lnum, col, list) abort
    let name = s:v_mark_name('mark')
    let ns_id = nvim_create_namespace(name)
    let s:ns_dict[name] = ns_id

    " nvim_buf_set_extmarkは0-basedなので、1を引く
    call nvim_buf_set_extmark(0, ns_id, a:lnum - 1, a:col - 1, {
          \   'virt_text': a:list,
          \   'virt_text_pos': 'inline',
          \ })
    " \   'right_gravity': v:false
  endfunction
else
  let s:prop_types = {}

  function s:export_hide() abort
    for k in s:prop_types->keys()
      call prop_remove({'type': k, 'all': v:true})
    endfor
  endfunction

  function s:v_mark_put(lnum, col, list) abort
    let cnt = 1
    for [text, hlname] in a:list
      call s:v_mark_put_single(a:lnum, a:col, $'cnt{cnt}', text, hlname ?? 'Normal')
      let cnt += 1
    endfor
  endfunction

  function s:v_mark_put_single(lnum, col, name, text, hl) abort
    let name = s:v_mark_name(a:name)

    let prop_type_def = {'highlight': a:hl}
    " let prop_type_def = {'highlight': a:hl, 'start_incl':1, 'end_incl':1}
    if get(s:prop_types, name, {}) != prop_type_def
      if prop_type_get(name)->empty()
        call prop_type_add(name, prop_type_def)
      else
        call prop_type_change(name, prop_type_def)
      endif
      let s:prop_types[name] = prop_type_def
    endif

    call prop_add(a:lnum, a:col, { 'type': name, 'text': a:text })
  endfunction
endif
