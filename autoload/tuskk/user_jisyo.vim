function s:export_add_word(context) abort
  let s:p1 = a:context.pos
  let s:p2 = getpos('.')[1:2]
  let s:opts = {'okuri': a:context.okuri, 'exclusive': !a:context.is_trailing}
  autocmd BufEnter <buffer> ++once call tuskk#henkan_buffer(s:p1, s:p2, s:opts)

  let yomi = a:context.machi .. a:context.consonant
  " let s:saved_context = a:context

  let target = a:context.okuri ==# '' ? 'nasi' : 'ari'

  let user_jisyo_winnr = bufwinnr(bufnr(tuskk#opts#get('user_jisyo_path')))
  if user_jisyo_winnr > 0
    " ユーザー辞書がすでに開いている場合は
    " okuri-ari/okuri-nasiの行へジャンプする
    execute user_jisyo_winnr .. 'wincmd w'
    normal! gg
    execute $'/okuri-{nasi}'
  else
    call s:export_open(target)
  endif

  call feedkeys($"\<c-o>o{yomi} //\<c-g>U\<left>\<cmd>call tuskk#enable()\<cr>", 'n')
endfunction

function s:export_open(target = '') abort
  let jump_line = ''
  if a:target ==# 'nasi'
    let jump_line = '+/okuri-nasi'
  elseif a:target ==# 'ari'
    let jump_line =  '+/okuri-ari'
  endif
  execute 'botright 5new' jump_line tuskk#opts#get("user_jisyo_path")
endfunction
