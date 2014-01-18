xquery version "3.0";

let $base-text :=
    <tei>
    <text n="x" xml:id="a">
            <div xml:id="b">
                <div xml:id="c">
                    <p xml:id="d">a<inline>a</inline>a</p>
                    <p xml:id="e">b<inline>b</inline>b</p>
                </div>
                <div xml:id="f">
                    <lg xml:id="g">
                        <l xml:id="h">c<inline>c</inline></l>
                        <l xml:id="i"><inline>d</inline>d</l>
                    </lg>
                    <lg xml:id="j">
                        <l xml:id="k">a
                            <inline>e</inline>
                        </l>
                        <l xml:id="l">f<inline>f</inline></l>
                    </lg>
                </div>
            </div>
        </text>
    </tei>

let $block-app := 
<text wit="y">
        <rdg><target>a</target><order>1</order><level>1</level><local-name>text</local-name></rdg>
        <rdg><target>b</target><order>2</order><level>2</level><local-name>div</local-name></rdg>
        <rdg><target>c</target><order>3</order><level>3</level><local-name>div</local-name></rdg>
        <rdg><target>e</target><order>4</order><level>4</level><local-name>p</local-name></rdg>
        <rdg><target>d</target><order>5</order><level>4</level><local-name>p</local-name></rdg>
        <rdg><target>m</target><order>6</order><level>4</level><contents><p xml:id="m">m<inline>m</inline>m</p></contents></rdg>
        <rdg><target>f</target><order>7</order><level>3</level><local-name>div</local-name></rdg>
        <rdg><target>j</target><order>8</order><level>4</level><local-name>lg</local-name></rdg>
        <rdg><target>k</target><order>9</order><level>5</level><local-name>l</local-name></rdg>
        <rdg><target>l</target><order>10</order><level>5</level><local-name>l</local-name></rdg>
    </text>

let $block-elements := ('text','div', 'p', 'lg', 'l')

let $base-text-elements :=
    for $element in ($base-text//*)[local-name(.) = $block-elements]
    return 
        if ($element/text()) 
        then element {local-name($element) }{ $element/@*, attribute{'depth'}{count($element/ancestor-or-self::node())-1}, $element/node()}
        else element {local-name($element) }{$element/@*, attribute{'depth'}{count($element/ancestor-or-self::node())-1},  ''} 

let $app-in-base-text :=
    for $rdg in $block-app/*
    return $base-text-elements[@xml:id eq $rdg/target]

let $base-text-ids :=
    $base-text//@xml:id/string()
let $log := util:log("DEBUG", ("##$base-text-ids): ", $base-text-ids))

let $app-not-in-base-text :=
    for $rdg in $block-app/*[not(./target = $base-text-ids)]
    return element {local-name($rdg/contents/*) }{ $rdg/@*, attribute{'depth'}{$rdg/level}, $rdg/contents/*}

let $reconstructed-text :=
        ($app-not-in-base-text, $app-in-base-text)

return $reconstructed-text