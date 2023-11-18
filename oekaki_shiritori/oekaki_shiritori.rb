#!/usr/bin/env ruby

require 'pp'
require 'dotenv/load'
require 'net/http'
require 'net/https'
require 'json'
require_relative 'openai_client'

# Azure OpenAI Service の予算の方が余っているのでAzure側を使いたいが、
# USリージョンではGPT-4モデルがまだデプロイできず、JPリージョンでは画像生成がまだ使えず、
# 全リージョンでまだVISION APIが使えない
# そのため、APIをはしごすることになってしまっている……。
# - 画像認識: OpenAI Client
# - しりとり応対: JPリージョン GPT-4
# - 画像生成: USリージョン DALL-E 2
vision_client = OpenAiClient.new(ENV.fetch('OPENAI_API_KEY'), ENV.fetch('OPENAI_ORG_KEY'))
chat_client = AzureClient.new(ENV.fetch('JP_ENDPOINT'), ENV.fetch('JP_API_KEY'), ENV.fetch('JP_DEPLOYMENT'))
dalle_client = AzureClient.new(ENV.fetch('US_ENDPOINT'), ENV.fetch('US_API_KEY'), ENV.fetch('US_DEPLOYMENT'))

class IllustrationChainer
  GET_NEXT_WORD_PROMPT = <<-HERE
  あなたはお絵描きしりとりの対戦者です。
  ユーザから単語がひとつ入力されます。
  入力の単語に対ししりとりが成立する次の単語を考え、その次の単語を英訳しつつ、日本語とふりがなと英訳された単語から画像を生成します。
  HERE

  GET_NEXT_WORD_FUNCTIONS = [
    {
      description: 'generate image from from Japanese and English words',
      name: 'convert_word_to_image',
      parameters: {
        type: 'object',
        properties: {
          word: { type: 'string', description: '単語' },
          ruby: { type: 'string', description: 'ふりがな' },
          english_word: { type: 'string', description: '英訳された単語' },
        },
        required: [ 'word', 'english_word' ],
      },
    },
  ]

  VISION_PROMPT = <<-HERE
  この画像は何のイラストでしょうか、ひらがな一単語で答えてください。
  ただし、単語の先頭は「%s」ではじまっている可能性が高く、単語の長さはひらがなで%d文字の単語です。
  必ず、ひらがな一単語で答えてください。
  HERE

  def initialize(chat_client, dalle_client, vision_client)
    @chat_client = chat_client
    @dalle_client = dalle_client
    @vision_client = vision_client
    @word_history = []
    @message_history = []
  end

  def detect_image(url, prefix_char, length, options = {})
    puts "画像を認識しています..."
    history = [
      {
        role: 'user',
        content: [
          { type: 'text', text: VISION_PROMPT % [prefix_char, length] },
          { type: 'image_url', image_url: { url: url }},
        ]
      }
    ]
    10.times do
      options.merge!(model: 'gpt-4-vision-preview')
      res = @vision_client.chat_completions(history, options)

      content = res.dig('choices', 0, 'message', 'content')
      if content.nil?
        p res
        next
      end
      word = extract_word(content, prefix_char, length)

      if word
        @message_history << res
        @word_history << { url: url, prefix_char: prefix_char, length: length, detect: word }
        return word
      end
    end
    raise "Failed to detect image"
  end

  def extract_word(content, prefix_char, length)
      # 「」で括ってあって、先頭文字と文字数一致が見つかれば最優先
      quoted = content.scan(/「(#{prefix_char}.{#{length-1}})」/)
      return quoted[rand(quoted.size)][0] unless quoted.empty?

      # 「」で括ってあって、文字数一致が見つかれば次点
      quoted = content.scan(/「(.{#{length}})」/)
      return quoted[rand(quoted.size)][0] unless quoted.empty?

      # 「」で括ってあって、二文字以上なら単語かも
      quoted = content.scan(/「(.{2,})」/)
      return quoted[rand(quoted.size)][0] unless quoted.empty?

      # 10文字以下なら単語で答えてくれているんじゃない？しらんけど
      return content if content.size < 10

      # 多分わからない
      return nil
  end

  def gen_next_word(word)
    puts "次の単語を考えています..."
    history = [
      { role: 'system', content: GET_NEXT_WORD_PROMPT },
      { role: 'user', content: "「#{word}」" },
    ]
    10.times do
      res = @chat_client.chat_completions(history, functions: GET_NEXT_WORD_FUNCTIONS)
      choice = res.dig('choices', 0)

      next if choice.dig('finish_reason') != 'function_call'

      method_name = choice.dig('message', 'function_call', 'name')
      method_args = JSON.parse(choice.dig('message', 'function_call', 'arguments'))
      result = send(method_name, method_args)

      @message_history << res
      @word_history << method_args
      return result
    end
    raise "Failed to generate next word"
  end

  def convert_word_to_image(obj)
    puts "画像を生成しています..."
    english_word = obj['english_word']
    url = @dalle_client.image_generations('Hand drawn with mouse, black-and-white line drawing of %s' % english_word, size: '256x256')
    obj.update(url: url)
  end

  def result
    {
      words: @word_history,
      message_history: @message_history,
    }
  end
end

HIRAGANAS = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほやゆよらりるれろわ'.each_char.to_a

prefix_char = HIRAGANAS[rand(HIRAGANAS.size)]
puts "しりとりの最初の文字は「#{prefix_char}」です"
puts "「ん」で終わる場合、一文字手前の文字を使います"
finished = false
begin
  chainer = IllustrationChainer.new(chat_client, dalle_client, vision_client)
  5.times do |i|
    url = begin
            puts "ラウンド#{i+1}: 単語を表す画像のURLを入力してください"
            STDIN.readline.strip.tap{|u| URI.parse(u) }
          rescue => e
            puts e
            retry
          end
    length = begin
               puts "何文字の単語ですか？"
               Integer(STDIN.readline.strip)
             rescue => e
               puts e
               retry
             end
    word = chainer.detect_image(url, prefix_char, length)

    res = chainer.gen_next_word(word)
    puts res[:url]
    puts res['ruby'].gsub(/./, '●')
    prefix_char = res['ruby'][-1]
    prefix_char = res['ruby'][-2] if %[ん ン].include?(prefix_char)
  end
  puts "結果を見るにはEnterを押してください"
  STDIN.readline

  chainer.result[:words].each do |word_history|
    puts "- 8<- - - - - - - -"
    if word_history.include?(:detect)
      # プレーヤーのターン
      puts word_history[:url]
      puts "文字数: #{word_history[:length]}"
      puts "予想先頭文字: #{word_history[:prefix_char]}"
      STDIN.readline
      puts "認識結果: #{word_history[:detect]}"
    else
      # GPTのターン
      puts word_history[:url]
      puts "文字数: #{word_history['ruby'].size}"
      STDIN.readline
      puts "単語: #{word_history['word']}(#{word_history['ruby']} / #{word_history['english_word']})"
    end
    STDIN.readline
  end
  finished = true
rescue => e
  puts "Error: #{e}"
  pp chainer.result
ensure
  pp chainer.result unless finished
end
