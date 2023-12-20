function user_jisyo#add_word(context) abort
  let s:p1 = a:context.pos
  let s:p2 = getpos('.')[1:2]
  let s:opts = {'okuri': a:context.okuri, 'exclusive': !a:context.is_trailing}
  autocmd BufEnter <buffer> ++once call tuskk#henkan_buffer(s:p1, s:p2, s:opts)

  let yomi = a:context.machi .. a:context.consonant
  " let s:saved_context = a:context

  let target = a:context.okuri ==# '' ? 'nasi' : 'ari'

  let user_jisyo_winnr = bufwinnr(bufnr(opts#get('user_jisyo_path')))
  if user_jisyo_winnr > 0
    " ユーザー辞書がすでに開いている場合は
    " okuri-ari/okuri-nasiの行へジャンプする
    execute user_jisyo_winnr .. 'wincmd w'
    normal! gg
    execute $'/okuri-{nasi}'
  else
    call user_jisyo#open(target)
  endif

  call feedkeys($"\<c-o>o{yomi} //\<c-g>U\<left>\<cmd>call tuskk#enable()\<cr>", 'n')
endfunction

function user_jisyo#open(target = '') abort
  let jump_line = ''
  if a:target ==# 'nasi'
    let jump_line = '+/okuri-nasi'
  elseif a:target ==# 'ari'
    let jump_line =  '+/okuri-ari'
  elseif a:target !=# ''
    throw '引数は空文字、"nasi"または"ari"のいずれかを指定してください'
  endif
  execute 'botright 5new' jump_line opts#get("user_jisyo_path")
endfunction
