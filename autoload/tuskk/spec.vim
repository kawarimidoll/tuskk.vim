let s:is_dict = {item -> type(item) == v:t_dict}

function s:export_get(key, preceding) abort
  " 先行入力と合わせて
  "   完成した
  "     辞書
  "     文字列
  "       半端がある
  "       半端がない→半端が空文字として判断できる
  "   完成していないが次なる先行入力の可能性がある
  " 先行入力を無視して単体で
  "   完成した→直前の先行入力を消すか分岐する必要がある
  "     辞書
  "     文字列
  "       半端がある
  "       半端がない→半端が空文字として判断できる
  "   完成していないが次なる先行入力の可能性がある
  " 完成していないし先行入力にもならない

  " string: バッファに書き出す文字列
  " store: ローマ字入力バッファの文字列（上書き）
  " その他：関数など func / mode / expr
  let spec = { 'key': a:key }

  let current = a:preceding .. a:key
  if has_key(tuskk#opts#get('kana_table'), current)
    let spec.reason = 'combined:found'
    " s:store.hanpaの残存文字と合わせて完成した場合
    if s:is_dict(tuskk#opts#get('kana_table')[current])
      call extend(spec, tuskk#opts#get('kana_table')[current])
      return spec
    endif
    let [kana, roma; _rest] = tuskk#opts#get('kana_table')[current]->split('\A*\zs') + ['']
    let spec.string = kana
    let spec.store = roma
    return spec
  elseif has_key(tuskk#opts#get('preceding_keys_dict'), current)
    let spec.reason = 'combined:probably'
    " 完成はしていないが、先行入力の可能性がある場合
    let spec.store = current
    return spec
  endif

  " ここまでで値がヒットせず、put_hanpaがfalseなら、
  " storeに残っていた半端な文字をバッファに載せずに消す
  let spec.string = tuskk#opts#get('put_hanpa') ? a:preceding : ''

  if has_key(tuskk#opts#get('kana_table'), a:key)
    let spec.reason = 'alone:found'
    " 先行入力を無視して単体で完成した場合
    if s:is_dict(tuskk#opts#get('kana_table')[a:key])
      call extend(spec, tuskk#opts#get('kana_table')[a:key])
      " 値が辞書ならput_hanpaに関らずstringは削除
      " storeに値を保存する
      let spec.string = ''
      let spec.store = a:preceding
    else
      let [kana, roma; _rest] = tuskk#opts#get('kana_table')[a:key]->split('\A*\zs') + ['']
      let spec.string ..= kana
      let spec.store = roma
    endif

    return spec
  elseif has_key(tuskk#opts#get('preceding_keys_dict'), a:key)
    let spec.reason = 'alone:probably'
    " 完成はしていないが、単体で先行入力の可能性がある場合
    let spec.store = a:key
    return spec
  endif

  let spec.reason = 'unfound'
  " ここまで完成しない（かなテーブルに定義が何もない）場合
  let spec.string ..= a:key
  let spec.store = ''
  return spec
endfunction

