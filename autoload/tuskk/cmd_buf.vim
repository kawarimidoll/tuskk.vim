function tuskk#cmd_buf#start() abort
  let cmdtype = getcmdtype()
  if ':/?' !~# cmdtype
    return
  endif

  let s:context = {
        \ 'type': cmdtype,
        \ 'text': getcmdline(),
        \ 'col': getcmdpos(),
        \ 'view': winsaveview(),
        \ 'winid': win_getid(),
        \ }

  botright 1new
  setlocal buftype=nowrite bufhidden=wipe noswapfile

  " CmdLeaveを発火させずにコマンドラインから脱出
  call feedkeys("\<c-c>", 'n')

  call setline(1, s:context.text)
  call cursor(1, s:context.col)

  if strlen(s:context.text) < s:context.col
    startinsert!
  else
    startinsert
  endif

  augroup cmd_buf_augroup
    autocmd!
    autocmd InsertEnter <buffer> ++once call tuskk#enable()
    " 直接記述すると即座に発火してしまうのでInsertEnterでラップする
    " 入力を終了したり改行したりしたタイミングでコマンドラインに戻って反映する
    autocmd InsertEnter <buffer> ++once
          \ autocmd TextChangedI,TextChangedP,InsertLeave <buffer>
          \   if line('$') > 1 || mode() != 'i'
          \ |   let s:context.line = s:context.type .. getline(1, '$')->join('')
          \ |   quit!
          \ |   call win_gotoid(s:context.winid)
          \ |   call winrestview(s:context.view)
          \ |   doautocmd WinEnter
          \ |   call feedkeys("\<esc>" .. s:context.line, 'ni')
          \ | endif
  augroup END
endfunction
