#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'optparse'
require 'mysql2'
require 'time'

$preset =
  [{ # 新番組チェック
     :title => %q([\[\(［【<]新[>】］\)\]]| 新$|第0*[1一―ー壱][話回夜弾]|[#＃♯](0*1|０*１)(?!\p{N})),
     :cate1 => "08",
     :band => %w( BS GR ),
   },
   { # 映画・アニメ
     :cate1 => "0702",
   },
  ]

$username = 'epgrec'
$database = 'epgrec'
$password = '??????'


$opt = {
  :band => [],
  :cate1 => nil,
  :cate2 => nil,
  :des  => nil,
  :title => nil,
  :preset => nil,
  :v     => nil,
}

Version = "1.0.0"

def usage()
  pname = File.basename($0)
  usageStr = <<"EOM"
Usage: #{pname} [Options]...

  Options:
  -b str      バンドの指定 GR,BS,CS (複数指定可)
  -c str      1st カテゴリの指定
  -C str      2nd カテゴリの指定
  -p n        preset の指定
  -t str      title 検索の正規表現
  -d str      description 検索の正規表現
  --pc        カテゴリの一覧表示
  --help      Show this help

#{pname} Ver #{Version}
EOM
  
    print usageStr
    exit 1
end


def setPreset( n )
  raise "preset No error" if $preset[n] == nil
  $preset[n].keys.each do |key|
    $opt[ key ] = $preset[n][key]
  end
end


#
#  カテゴリ名を表示
#
def printCate()
  $cateL1.keys.sort.each do |n|
    printf("%2s %s\n",n, $cateL1[n])
    if $cateL2[ n ] != nil
      $cateL2[n].keys.sort.each do |m|
        printf("    %4s %s\n",m, $cateL2[n][m])
      end
    end
  end
end




def makeCateSql()
  cate = []
  r = nil
  c = $opt[:cate1]
  if c != nil
    if ( r = getCate( c )) == nil
      printf("Error: can not find category %s\n",c)
      exit
    else
      tmp = []
      tmp << " p.category_id = #{r[0]} "
      tmp << " p.sub_genre = #{r[1]} " if r.size > 1
      cate << "( " + tmp.join(" and ") + " )"
    end
  end

  c = $opt[:cate2]
  if c != nil
    if ( r = getCate( c )) == nil
      printf("Error: can not find category %s\n",c)
      exit
    else
      tmp = []
      tmp << " p.genre2 = #{r[0]} "
      tmp << " p.sub_genre2 = #{r[1]} " if r.size > 1
      cate << "( " + tmp.join(" and ") + " )"
    end
  end
  
  r = "( " + cate.join(" or ") + " )" if cate.size > 0
  r
end




#
# テレビ番組カテゴリー一覧 ARIB STD-B10 
#

$cateL1 = {
  "01" => "ニュース/報道",
  "02" => "スポーツ",
  "03" => "情報/ワイドショー",
  "04" => "ドラマ",
  "05" => "音楽",
  "06" => "バラエティ",
  "07" => "映画",
  "08" => "アニメ/特撮",
  "09" => "ドキュメンタリー/教養",
  "10" => "劇場/公演",
  "11" => "趣味/教育",
  "12" => "福祉",
  #13 => "拡張",
  #15 => "その他",
}

# 
$cateL2 = {
  "01" => {
    "0100" => "定時・総合",
    "0101" => "天気",
    "0102" => "特集・ドキュメント",
    "0103" => "政治・国会",
    "0104" => "経済・市況",
    "0105" => "海外・国際",
    "0106" => "解説",
    "0107" => "討論・会談",
    "0108" => "報道特番",
    "0109" => "ローカル・地域",
    "0110" => "交通",
    "0115" => "その他"
  },
  "02" => {
    "0200" => "スポーツニュース",
    "0201" => "野球",
    "0202" => "サッカー",
    "0203" => "ゴルフ",
    "0204" => "その他の球技",
    "0205" => "相撲・格闘技",
    "0206" => "オリンピック・国際大会",
    "0207" => "マラソン・陸上・水泳",
    "0208" => "モータースポーツ",
    "0209" => "マリン・ウィンタースポーツ",
    "0210" => "競馬・公営競技",
    "0215" => "その他",
  },
  "03" => {
    "0300" => "芸能・ワイドショー",
    "0301" => "ファッション",
    "0302" => "暮らし・住まい",
    "0303" => "健康・医療",
    "0304" => "ショッピング・通販",
    "0305" => "グルメ・料理",
    "0306" => "イベント",
    "0307" => "番組紹介・お知らせ",
	"0315" => "その他",
  },
  "04" => {
    "0400" => "国内ドラマ",
    "0401" => "海外ドラマ",
    "0402" => "時代劇",
    "0415" => "その他",
  },
  "05" => {
    "0500" => "国内ロック・ポップス",
    "0501" => "海外ロック・ポップス",
    "0502" => "クラシック・オペラ",
    "0503" => "ジャズ・フュージョン",
    "0504" => "歌謡曲・演歌",
    "0505" => "ライブ・コンサート",
    "0506" => "ランキング・リクエスト",
    "0507" => "カラオケ・のと゛自慢",
    "0508" => "民謡・邦楽",
    "0509" => "童謡・キッズ",
	"0510" => "民族音楽・ワールドミュージック",
    "0515" => "その他",
  },
  "06" => {
    "0600" => "クイズ",
    "0601" => "ゲーム",
    "0602" => "トークバラエティ",
    "0603" => "お笑い・コメディ",
    "0604" => "音楽バラエティ",
    "0605" => "旅バラエティ",
    "0606" => "料理バラエティ",
    "0615" => "その他",
  },
  "07" => {
    "0700" => "洋画",
    "0701" => "邦画",
    "0702" => "アニメ",
    "0715" => "その他",
  },
  "08" => {
    "0800" => "国内アニメ",
    "0801" => "海外アニメ",
    "0802" => "特撮",
    "0815" => "その他",
  },
  "09" => {
    "0900" => "社会・時事",
    "0901" => "歴史・紀行",
    "0902" => "自然・動物・環境",
    "0903" => "宇宙・科学・医学",
    "0904" => "カルチャー・伝統文化",
    "0905" => "文学・文芸",
    "0906" => "スポーツ",
    "0907" => "ドキュメンタリー全般",
    "0908" => "インタビュー・討論",
    "0915" => "その他",
  },
  "10" => {
    "1000" => "現代劇・新劇",
    "1001" => "ミュージカル",
    "1002" => "ダンス・バレエ",
    "1003" => "落語・演芸",
    "1004" => "歌舞伎・古典",
    "1015" => "その他",
  },
  "11" => {
    "1100" => "旅・釣り・アウトドア",
    "1101" => "園芸・ペット・手芸",
    "1102" => "音楽・美術・工芸",
    "1103" => "囲碁・将棋",
    "1104" => "麻雀・パチンコ",
    "1105" => "車・オートバイ",
    "1106" => "コンピュータ・TVゲーム",
    "1107" => "会話・語学",
    "1108" => "幼児・小学生",
    "1109" => "中学生・高校生",
    "1110" => "大学生・受験",
    "1111" => "生涯教育・資格",
    "1112" => "教育問題",
    "1115" => "その他",
  },
  "12" => {
    "1200" => "高齢者",
    "1201" => "障害者",
    "1202" => "社会福祉",
    "1203" => "ボランティア",
    "1204" => "手話",
    "1205" => "文字(字幕)",
    "1206" => "音声解説",
    "1215" => "その他",
  },
}



#
#  カテゴリ名から ID を取得
#
def getCate( cate )

  c1 = c2 = nil
  if cate =~ /^(\d\d)(\d\d)$/
    c1 = $1
    c2 = $2
  elsif cate =~ /^(\d\d)$/
    c1 = $1
  end
  if $cateL1[ c1 ] != nil
    if c2 != nil
      if $cateL2[c1][cate] != nil
        return [ c1.to_i, c2.to_i ]
      end
    else
      return [ c1.to_i ]
    end
  end
  nil
end

class String
 
  def mb_ljust(width, padding=' ')
    output_width = each_char.map{|c| if c == "−" then 1 else c.bytesize == 1 ? 1 : 2 end }.reduce(0, &:+)
    padding_size = [0, width - output_width].max
    self + padding * padding_size
  end
 
end


if ARGV.size == 0
  setPreset( 0 )
else
  OptionParser.new do |opt|
    opt.on('--pc') { printCate(); exit }     # カテゴリの一覧表示
    opt.on('-b n') {|v| $opt[:band] << v }   # バンドの指定 GR,BS,CS
    opt.on('-c n') {|v| $opt[:cate1] = v }   # 1st カテゴリの指定
    opt.on('-C n') {|v| $opt[:cate2] = v }   # 2nd カテゴリの指定
    opt.on('-p n') {|v| setPreset(v.to_i) }  # preset の指定
    opt.on('-t n') {|v| $opt[:title] = v }   # title 検索の正規表現
    opt.on('-d n') {|v| $opt[:des] = v }     # description 検索の正規表現
    opt.on('-v')   { $opt[:v] = true }       # verbose
    opt.on('--help'){ usage(); exit }
    opt.parse!(ARGV)
  end
end


client = Mysql2::Client.new(:host => 'localhost',
                            :username => $username,
                            :password => $password,
                            :encoding => 'utf8',
                            :database => $database )


#
#   予約状況の取得
#
reserve = []
results = client.query('select * from Recorder_reserveTbl')
results.each do |row|
  reserve << row
end

band = []
$opt[ :band ].each {|t| band << sprintf("p.type = '%s'",t) }
band = band.join(" or ")
cate = makeCateSql()

sql = %( select * from Recorder_programTbl p 
         join Recorder_channelTbl c 
         on p.channel_disc=c.channel_disc )
wh = []
wh << "( #{band} ) " if band.size > 0
wh << cate if cate != nil
if wh.size > 0
  sql += "\nwhere " + wh.join(" and ")
end
sql += " order by p.starttime"

n = 1
now = Time.now
results = client.query(sql)
results.each do |row|
  next if row["starttime"] < now

  flag = false
  if $opt[:title] != nil and row[ "title" ]  =~ /#{$opt[:title]}/
    flag = true
  end

  if $opt[:des] != nil and row[ "description" ] =~ /#{$opt[:des]}/
    flag = true
  end

  if $opt[:title] == nil and $opt[:des] == nil 
    flag = true
  end
  
  #puts row
  if flag == true
    date = row["starttime"].strftime("%m/%d %H:%M")
    chname = row[ "name" ].mb_ljust(20)
    mark = "  "
    reserve.each do |r|
      if row["starttime"] == r["starttime"] and row["channel_disc"] == r["channel_disc"]
        mark = "予"
      end
    end
    
    printf("%3d %s %s %s %s\n",n,mark, date,chname,row[ "title" ] )
    n += 1
  end

end

client.close

