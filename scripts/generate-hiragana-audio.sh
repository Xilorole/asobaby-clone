#!/usr/bin/env bash
#
# generate-hiragana-audio.sh
# Azure Neural TTS を使ってひらがなカードの音声ファイルを一括生成する。
#
# 前提: az cli にログイン済み & Speech Service リソースが作成済み
#
# 使い方:
#   # 方法1: az cli でリソースからキーを自動取得
#   ./scripts/generate-hiragana-audio.sh \
#       --resource-group <RG_NAME> \
#       --resource-name <SPEECH_RESOURCE_NAME> \
#       --region <REGION>
#
#   # 方法2: キーを直接指定
#   AZURE_SPEECH_KEY="xxxxx" AZURE_SPEECH_REGION="japaneast" \
#       ./scripts/generate-hiragana-audio.sh
#
set -euo pipefail

# ─── 定数 ──────────────────────────────────────────

VOICE="ja-JP-NanamiNeural"
OUTPUT_FORMAT="audio-16khz-64kbitrate-mono-mp3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/android/app/src/main/assets/audio/hiragana"

# ─── 引数パース ────────────────────────────────────

RESOURCE_GROUP=""
RESOURCE_NAME=""
REGION="${AZURE_SPEECH_REGION:-}"
SPEECH_KEY="${AZURE_SPEECH_KEY:-}"

FORCE=false
WORDS_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
        --resource-name)  RESOURCE_NAME="$2";  shift 2 ;;
        --region)         REGION="$2";         shift 2 ;;
        --voice)          VOICE="$2";          shift 2 ;;
        --force)          FORCE=true;          shift ;;
        --words-only)     WORDS_ONLY=true;     shift ;;
        --help|-h)
            echo "Usage: $0 [--resource-group RG] [--resource-name NAME] [--region REGION] [--voice VOICE] [--force] [--words-only]"
            echo ""
            echo "Options:"
            echo "  --resource-group  Azure resource group name"
            echo "  --resource-name   Azure Speech Service resource name"
            echo "  --region          Azure region (e.g. japaneast)"
            echo "  --voice           TTS voice name (default: ja-JP-NanamiNeural)"
            echo "  --force           Overwrite existing audio files"
            echo "  --words-only      Only generate word audio (skip single characters)"
            echo ""
            echo "Environment variables:"
            echo "  AZURE_SPEECH_KEY    Speech Service key (skips az cli lookup)"
            echo "  AZURE_SPEECH_REGION Region (e.g. japaneast)"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ─── キー取得 ──────────────────────────────────────

if [[ -z "$SPEECH_KEY" ]]; then
    if [[ -z "$RESOURCE_GROUP" || -z "$RESOURCE_NAME" ]]; then
        echo "Error: AZURE_SPEECH_KEY が未設定の場合は --resource-group と --resource-name が必要です。"
        echo "  ./scripts/generate-hiragana-audio.sh --resource-group <RG> --resource-name <NAME> --region <REGION>"
        exit 1
    fi
    echo "🔑 az cli で Speech Service キーを取得中..."
    SPEECH_KEY=$(az cognitiveservices account keys list \
        --resource-group "$RESOURCE_GROUP" \
        --name "$RESOURCE_NAME" \
        --query "key1" -o tsv)

    if [[ -z "$REGION" ]]; then
        echo "📍 az cli でリージョンを取得中..."
        REGION=$(az cognitiveservices account show \
            --resource-group "$RESOURCE_GROUP" \
            --name "$RESOURCE_NAME" \
            --query "location" -o tsv)
    fi
fi

if [[ -z "$REGION" ]]; then
    echo "Error: リージョンが指定されていません。--region または AZURE_SPEECH_REGION を設定してください。"
    exit 1
fi

echo "✅ リージョン: $REGION / ボイス: $VOICE"

# ─── 音声テキスト一覧 ──────────────────────────────
# format: "ファイル名(拡張子なし) テキスト"
# 単独文字はゆっくり明瞭に読むようSSMLで調整

# format: "ファイル名(拡張子なし) TTSテキスト"
# ファイル名はひらがな、TTSテキストは漢字/カタカナでイントネーション改善

TEXTS=(
    # ひらがな文字（単独） — 46文字
    "char_あ あ"
    "char_い い"
    "char_う う"
    "char_え え"
    "char_お お"
    "char_か か"
    "char_き き"
    "char_く く"
    "char_け け"
    "char_こ こ"
    "char_さ さ"
    "char_し し"
    "char_す す"
    "char_せ せ"
    "char_そ そ"
    "char_た た"
    "char_ち ち"
    "char_つ つ"
    "char_て て"
    "char_と と"
    "char_な な"
    "char_に に"
    "char_ぬ ぬ"
    "char_ね ね"
    "char_の の"
    "char_は は"
    "char_ひ ひ"
    "char_ふ ふ"
    "char_へ へ"
    "char_ほ ほ"
    "char_ま ま"
    "char_み み"
    "char_む む"
    "char_め め"
    "char_も も"
    "char_や や"
    "char_ゆ ゆ"
    "char_よ よ"
    "char_ら ら"
    "char_り り"
    "char_る る"
    "char_れ れ"
    "char_ろ ろ"
    "char_わ わ"
    "char_を を"
    "char_ん ん"
    # 単語 — 全てひらがな + prosody contour でアクセント制御
    "word_あひる あひる"
    "word_いぬ いぬ"
    "word_うし うし"
    "word_えんぴつ えんぴつ"
    "word_おに おに"
    "word_かに かに"
    "word_きつね きつね"
    "word_くま くま"
    "word_けいさつ けいさつ"
    "word_こおり こおり"
    "word_さかな さかな"
    "word_しか しか"
    "word_すいか すいか"
    "word_せんたくき せんたくき"
    "word_そら そら"
    "word_たこ たこ"
    "word_ちょうちょ ちょうちょ"
    "word_つき つき"
    "word_てがみ てがみ"
    "word_とり とり"
    "word_なす なす"
    "word_にじ にじ"
    "word_ぬいぐるみ ぬいぐるみ"
    "word_ねこ ねこ"
    "word_のりもの のりもの"
    "word_はな はな"
    "word_ひつじ ひつじ"
    "word_ふね ふね"
    "word_へび へび"
    "word_ほし ほし"
    "word_まいく まいく"
    "word_みかん みかん"
    "word_むぎ むぎ"
    "word_めがね めがね"
    "word_もみじ もみじ"
    "word_やぎ やぎ"
    "word_ゆき ゆき"
    "word_よっと よっと"
    "word_らいおん らいおん"
    "word_りんご りんご"
    "word_ぼーる ぼーる"
    "word_れもん れもん"
    "word_ろけっと ろけっと"
    "word_わに わに"
    "word_かばん かばん"
)

# ─── SSML 生成関数 ─────────────────────────────────

# ピッチアクセント補正が必要な単語の SSML prosody を返す
# 東京式アクセント (NHK日本語発音アクセント辞典準拠):
#   2モーラ LH (平板型[0]/尾高型[2]): (0%,-4st)(40%,+0st)(100%,+3st)
#   2モーラ HL (頭高型[1]):            (0%,+3st)(50%,+0st)(100%,-4st)
#   3モーラ LHH (平板型[0]):           (0%,-3st)(25%,+1st)(100%,+2st)
#   3モーラ HLL (頭高型[1]):           (0%,+3st)(30%,+1st)(60%,-1st)(100%,-4st)
#   4モーラ LHHL (中高型[3]):          (0%,-3st)(15%,+2st)(60%,+2st)(80%,-1st)(100%,-4st)
#   6モーラ LHHHHH (平板型[0]):        (0%,-2st)(10%,+1st)(100%,+1st)
get_pitch_override() {
    local filename="$1"
    local text="$2"
    case "$filename" in
        # 2モーラ LH: 平板型[0] / 尾高型[2]
        word_いぬ)          echo "<prosody contour='(0%,-4st)(40%,+0st)(100%,+3st)'>${text}</prosody>" ;;
        word_おに)          echo "<prosody contour='(0%,-4st)(40%,+0st)(100%,+3st)'>${text}</prosody>" ;;
        word_しか)          echo "<prosody contour='(0%,-4st)(40%,+0st)(100%,+3st)'>${text}</prosody>" ;;
        word_つき)          echo "<prosody contour='(0%,-4st)(40%,+0st)(100%,+3st)'>${text}</prosody>" ;;

        # 2モーラ HL: 頭高型[1]
        word_そら)          echo "<prosody contour='(0%,+3st)(50%,+0st)(100%,-4st)'>${text}</prosody>" ;;
        word_ねこ)          echo "<prosody contour='(0%,+3st)(50%,+0st)(100%,-4st)'>${text}</prosody>" ;;
        word_ふね)          echo "<prosody contour='(0%,+3st)(50%,+0st)(100%,-4st)'>${text}</prosody>" ;;
        # 3モーラ LHH: 平板型[0]
        word_あひる)        echo "<prosody contour='(0%,-6st)(30%,+3st)(100%,+4st)'>${text}</prosody>" ;;
        word_さかな)        echo "<prosody contour='(0%,-3st)(25%,+1st)(100%,+2st)'>${text}</prosody>" ;;
        # 3モーラ LHH: 平板型[0]
        word_こおり)        echo "<prosody contour='(0%,-3st)(25%,+1st)(100%,+2st)'>${text}</prosody>" ;;
        word_てがみ)        echo "<prosody contour='(0%,-3st)(25%,-1st)(100%,+0st)'>${text}</prosody>" ;;

        # 5モーラ LHHHL: 中高型[4] せんたくき
        word_せんたくき)    echo "<prosody contour='(0%,-3st)(10%,+2st)(60%,+2st)(75%,-1st)(100%,-4st)'>${text}</prosody>" ;;
        *) echo "" ;;
    esac
}

# SAPI phoneme でアクセントを直接制御する単語
# カタカナ + ' でアクセント核位置を指定 (直後にピッチが下がる)
get_sapi_phoneme() {
    local filename="$1"
    local text="$2"
    case "$filename" in
        word_ちょうちょ)  echo "<phoneme alphabet='sapi' ph=\"チョ'ウチョ\">${text}</phoneme>" ;;
        word_ぼーる)      echo "<phoneme alphabet='sapi' ph='ボール'>${text}</phoneme>" ;;
        word_みかん)      echo "<phoneme alphabet='sapi' ph=\"ミ'カン\">${text}</phoneme>" ;;
        word_よっと)      echo "<phoneme alphabet='sapi' ph=\"ヨ'ット\">${text}</phoneme>" ;;
        *) echo "" ;;
    esac
}

build_ssml() {
    local text="$1"
    local filename="$2"

    if [[ "$filename" == char_* ]]; then
        # 単独文字: ゆっくり・はっきり読む
        cat <<EOF
<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='ja-JP'>
  <voice name='${VOICE}'>
    <prosody rate='slow' pitch='+5%'>${text}</prosody>
  </voice>
</speak>
EOF
    else
        # 1) SAPI phoneme でアクセント制御 (最優先)
        local phoneme
        phoneme=$(get_sapi_phoneme "$filename" "$text")
        if [[ -n "$phoneme" ]]; then
            cat <<EOF
<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='ja-JP'>
  <voice name='${VOICE}'>
    ${phoneme}
  </voice>
</speak>
EOF
        else
            # 2) prosody contour でピッチ補正
            local override
            override=$(get_pitch_override "$filename" "$text")
            if [[ -n "$override" ]]; then
                cat <<EOF
<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='ja-JP'>
  <voice name='${VOICE}'>
    ${override}
  </voice>
</speak>
EOF
            else
                # 3) 通常読み上げ
                cat <<EOF
<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='ja-JP'>
  <voice name='${VOICE}'>
    <prosody rate='medium'>${text}</prosody>
  </voice>
</speak>
EOF
            fi
        fi
    fi
}

# ─── メイン処理 ────────────────────────────────────

mkdir -p "$OUTPUT_DIR"

TTS_ENDPOINT="https://${REGION}.tts.speech.microsoft.com/cognitiveservices/v1"

total=${#TEXTS[@]}
current=0
failed=0

echo ""
echo "🎙  音声生成開始 ($total 個)"
echo "   出力先: $OUTPUT_DIR"
echo ""

for entry in "${TEXTS[@]}"; do
    filename="${entry%% *}"
    text="${entry#* }"
    output_file="$OUTPUT_DIR/${filename}.mp3"
    current=$((current + 1))

    # --words-only: char_ をスキップ
    if [[ "$WORDS_ONLY" == true ]] && [[ "$filename" == char_* ]]; then
        echo "  [$current/$total] ⏭  ${filename}.mp3 (文字・スキップ)"
        continue
    fi

    # 既存ファイルがあればスキップ (--force で上書き)
    if [[ -f "$output_file" ]] && [[ "$FORCE" != true ]]; then
        echo "  [$current/$total] ⏭  ${filename}.mp3 (既存・スキップ)"
        continue
    fi

    ssml=$(build_ssml "$text" "$filename")

    printf "  [%d/%d] 🔊 %-20s → %s ... " "$current" "$total" "$text" "${filename}.mp3"

    http_code=$(curl -s -o "$output_file" -w "%{http_code}" \
        -X POST "$TTS_ENDPOINT" \
        -H "Ocp-Apim-Subscription-Key: ${SPEECH_KEY}" \
        -H "Content-Type: application/ssml+xml" \
        -H "X-Microsoft-OutputFormat: ${OUTPUT_FORMAT}" \
        -H "User-Agent: AsobabyTTSGenerator" \
        -d "$ssml")

    if [[ "$http_code" == "200" ]]; then
        file_size=$(wc -c < "$output_file" | tr -d ' ')
        echo "✅ (${file_size} bytes)"
    else
        echo "❌ (HTTP $http_code)"
        cat "$output_file" 2>/dev/null  # エラーレスポンスの表示
        echo ""
        rm -f "$output_file"
        failed=$((failed + 1))
    fi

    # レートリミット対策: 100ms 待機
    sleep 0.1
done

echo ""
echo "──────────────────────────────────"
if [[ $failed -eq 0 ]]; then
    echo "✅ 全 $total 件の音声ファイルを生成しました！"
else
    echo "⚠️  $((total - failed))/$total 件成功、$failed 件失敗"
fi
echo "   出力先: $OUTPUT_DIR"
echo ""

# ─── ファイルサイズ合計 ────────────────────────────

if command -v du &>/dev/null; then
    total_size=$(du -sh "$OUTPUT_DIR" | cut -f1)
    echo "📦 合計サイズ: $total_size"
fi
