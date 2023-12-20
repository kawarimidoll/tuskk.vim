" namespaceのキーまたはproptypeにファイルパスを使い、
" 名前が他のプラグインとぶつかるのを防ぐ
let s:file_name = expand('%:p')
let s:default_hl = 'Normal'

function inline_mark#put_text(name, text, hl = '') abort
  let pos = inline_mark#get(a:name)
  let [lnum, col] = empty(pos) ? getcurpos('.')[1:2] : pos
  call inline_mark#put(lnum, col, { 'name': a:name, 'text': a:text, 'hl': a:hl })
endfunction

if has('nvim')
  let s:ns_dict = {}

  function inline_mark#clear(name = '') abort
    if a:name ==# ''
      call nvim_buf_clear_namespace(0, -1, 0, -1)
      let s:ns_dict = {}
    elseif has_key(s:ns_dict, a:name)
      call nvim_buf_clear_namespace(0, s:ns_dict[a:name], 0, -1)
      call remove(s:ns_dict, a:name)
    endif
  endfunction

  function inline_mark#get(name) abort
    if has_key(s:ns_dict, a:name)
      let extmarks = nvim_buf_get_extmarks(0, s:ns_dict[a:name], 0, -1, {'limit':1})
      " extmarks = [ [extmark_id, row, col], ... ]
      if !empty(extmarks) && len(extmarks[0]) == 3
        return [extmarks[0][1]+1, extmarks[0][2]+1]
      endif
    endif
    return []
  endfunction

  function inline_mark#put(lnum, col, opts = {}) abort
    let hl = get(a:opts, 'hl', '')->empty() ? s:default_hl : a:opts.hl
    let text = get(a:opts, 'text', '')
    let name = get(a:opts, 'name', s:file_name)

    call inline_mark#clear(name)
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

  function inline_mark#clear(name = '') abort
    if a:name ==# ''
      for k in s:prop_types->keys()
        call inline_mark#clear(k)
      endfor
    elseif has_key(s:prop_types, a:name)
      call prop_remove({'type': a:name, 'all': v:true})
    endif
  endfunction

  function inline_mark#get(name) abort
    if prop_type_get(a:name)->empty()
      return []
    endif
    let prop = prop_find({'type': a:name, 'lnum': 1})
    return empty(prop) ? [] : [prop.lnum, prop.col]
  endfunction

  function inline_mark#put(lnum, col, opts = {}) abort
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
    call inline_mark#clear(name)

    call prop_add(a:lnum, a:col, { 'type': name, 'text': text })
  endfunction
endif
