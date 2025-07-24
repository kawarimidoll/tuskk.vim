function s:url_encode(str)
  return range(0, strlen(a:str)-1)
        \ ->map({i -> a:str[i] =~ '[-.~]\|\w' ? a:str[i] : printf("%%%02x", char2nr(a:str[i]))})
        \ ->join('')
endfunction

function tuskk#google_cgi#henkan(str) abort
  let url_base = 'http://www.google.com/transliterate?langpair=ja-Hira|ja&text='
  let encoded = s:url_encode(a:str)
  let result = system($"curl -s '{url_base}{encoded}'")

  " curlの実行エラーチェック
  if v:shell_error != 0
    call tuskk#utils#echoerr('Google CGI APIの呼び出しに失敗しました')
    return ''
  endif

  try
    " Google CGI APIは以下の形式の応答を想定している:
    " [["よみ1", ["候補1", "候補2", ...]], ["よみ2", ["候補1", "候補2", ...]], ...]
    " APIの返り値の型は信頼し、コード中で検証は行わない
    return json_decode(result)->map({_,v->v[1][0]})->join('')
  catch
    call tuskk#utils#echoerr('Google CGI APIのレスポンス解析に失敗しました: ' .. v:exception)
    return ''
  endtry
endfunction
