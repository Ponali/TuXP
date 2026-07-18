function getFakeName {
    local n="$1"

    # remove accents
    n="$(printf '%s' "$n" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null)"

    # lowercase
    n="${n,,}"

    # replace anything that isn't a-z, 0-9 or _
    n="$(printf '%s' "$n" | sed -E 's/[^a-z0-9]+/_/g')"

    # remove unnecesary underscores
    n=${n##_}
    n=${n%%_}

    printf '%s\n' "$n"
}
