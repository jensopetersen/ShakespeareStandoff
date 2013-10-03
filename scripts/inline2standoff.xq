xquery version "3.0";

declare boundary-space preserve;

declare function local:remove-elements($nodes as node()*, $remove as xs:anyAtomicType+)  as node()* {
   for $node in $nodes
   return
     if ($node instance of element())
     then 
        if ((local-name($node) = $remove))
        then ()
        else element {node-name($node)}
                {$node/@*,
                  local:remove-elements($node/node(), $remove)}
     else 
        if ($node instance of document-node())
        then local:remove-elements($node/node(), $remove)
        else $node
} ;

declare function local:get-top-level-nodes-base-layer($input as element(), $edition-layer-elements) {
    for $node in $input/node()
        let $base-before-element := string-join(local:separate-layers($node/preceding-sibling::node(), 'base'))
        let $base-before-text := string-join($node/preceding-sibling::text())
        let $marked-up-string := string-join(local:separate-layers(<node>{$node}</node>, 'base'))
        let $position-start := 
            string-length($base-before-element) + 
            string-length($base-before-text)
        let $position-end := $position-start + string-length($marked-up-string)
        return
            <node type="{
                if ($node instance of text())
                then 'text'
                else 
                    if ($node instance of element())
                    then 'element'
                    else ()
                }" xml:id="{concat('uuid-', util:uuid())}" status="{
                    let $base-text := string-join(local:separate-layers($input, 'base'))
                    let $before := substring($base-text, $position-start, 1)
                    let $after := substring($base-text, $position-end + 1, 1)
                    let $before-after := concat($before, $after)
                    let $before-after := replace($before-after, '\s|\p{P}', '')
                    return
                    if ($before-after) then "string" else "token"}">
                <target type="range" layer="{
                    if (local-name($node) = $edition-layer-elements) 
                    then 'edition' 
                    else 
                        if ($node instance of element())
                        then 'feature'
                        else 'text'}">
                    <base-layer>
                        <id>{string($node/../@xml:id)}</id>
                        <start>{if ($position-end eq $position-start) then $position-start else $position-start + 1}</start>
                        <offset>{$position-end - $position-start}</offset>
                    </base-layer>
                </target>
                <body>{
                    if ($node instance of text()) 
                    then replace($node, ' ', '&#x20;') 
                    else $node}</body>
                <layer-offset-difference>{
                    let $off-set-difference :=
                        if (name($node) = $edition-layer-elements or $node//app or $node//choice) 
                        then 
                            if (($node//app or name($node) = 'app') and $node//lem) 
                            then string-length(string-join($node//lem)) - string-length(string-join($node//rdg))
                            else 
                                if (($node//app or name($node) = 'app') and $node//rdg) 
                                then 
                                    let $non-base := string-length($node//rdg[@wit ne '#base'])
                                    let $base := string-length($node//rdg[@wit eq '#base'])
                                        return 
                                            $non-base - $base
                                else
                                    if ($node//choice or name($node) = 'choice') 
                                    then string-length($node//reg) - string-length($node//sic)
                                    else 0
                        else 0            
                            return $off-set-difference}</layer-offset-difference>
            </node>
};

declare function local:insert-element($node as node()?, $new-node as node(), 
    $element-name-to-check as xs:string, $location as xs:string) {
        if (local-name($node) eq $element-name-to-check)
        then
            if ($location eq 'before')
            then ($new-node, $node) 
            else 
                if ($location eq 'after')
                then ($node, $new-node)
                else
                    if ($location eq 'first-child')
                    then element {node-name($node)}
                        {
                            $node/@*
                            ,
                            $new-node
                            ,
                            for $child in $node/node()
                                return  $child
                        }
                    else
                        if ($location eq 'last-child')
                        then element {node-name($node)}
                            {
                                $node/@*
                                ,
                                for $child in $node/node()
                                    return $child 
                                ,
                                $new-node
                            }
                        else () (:The $element-to-check is removed if none of the four options are used.:)
        else
            if ($node instance of element()) 
            then
                element {node-name($node)} {
                    $node/@*
                    , 
                    for $child in $node/node()
                        return 
                            local:insert-element($child, $new-node, $element-name-to-check, $location) 
            }
         else $node
};

declare function local:insert-authoritative-layer($nodes as element()*) as element()* {
    for $node in $nodes/*
    
        let $id := concat('uuid-', util:uuid($node/target/base-layer/id))
        let $sum-of-previous-offsets := sum($node/preceding-sibling::node/layer-offset-difference, 0)
        let $base-level-start := $node/target/base-layer/start cast as xs:integer
        let $authoritative-layer-start := $base-level-start + $sum-of-previous-offsets
        let $layer-offset := $node/target/base-layer/offset/number() + $node/layer-offset-difference
        let $authoritative-layer := <authoritative-layer><id>{$id}></id><start>{$authoritative-layer-start}</start><offset>{$layer-offset}</offset></authoritative-layer>
            return
                local:insert-element($node, $authoritative-layer, 'base-layer', 'after')
};

declare function local:separate-layers($nodes as node()*, $target) as item()* {
    for $node in $nodes/node()
        return
            typeswitch($node)
                
                case text() return if ($node/ancestor-or-self::element(note)) then () else $node/string()
                (:NB: it is not clear what to do with "original annotations", e.g. notes in the original. Probably they should be collected on the same level as "edition" and "feature" (along with other instances of "misplaced text"). 
                Here we strip out all notes.:)
                
                case element(lem) return if ($target eq 'base') then () else $node/string()
                case element(rdg) return 
                    if ($target eq 'base' and not($node/../lem))
                    then $node[@wit eq '#base']/string() 
                    else
                        if ($target ne 'base' and not($node/../lem))
                        then $node[@wit ne '#base']/string() 
                        else
                            if ($target eq 'base' and $node/../lem)
                            then $node/string()
                            else ()
                
                case element(reg) return if ($target eq 'base') then () else $node/string()
                case element(sic) return if ($target eq 'base') then $node/string() else ()
                
                    default return local:separate-layers($node, $target)
};

declare function local:handle-element-annotations($node as node()) as item()* {
            let $layer-1-body-contents := $node//body/*(:get element below body - this can ony be a single element:)
            let $layer-1-body-contents := element {node-name($layer-1-body-contents)}{
                for $attribute in $layer-1-body-contents/@*
                    return attribute {name($attribute)} {$attribute}} (:construct empty element with attributes:)
            let $layer-1 := local:remove-elements($node, 'body')(:remove the body,:)
            let $layer-1 := local:insert-element($layer-1, <body>{$layer-1-body-contents}</body>, 'target', 'after')(:and insert the new body:)
                return $layer-1
            ,(:return the old annotation, with empty element below body and the new ones, with contents below this split over several annotations:)
            let $layer-1-id := $node/@xml:id/string()(:get id and:)
            let $layer-1-status := $node/@status/string()(:status of original annotation:)
            let $layer-2-body-contents := $node//body/*/*(:get the contents of what is below the body - the empty element in layer-1; there may be multiple elements here.:)
            for $element at $i in $layer-2-body-contents
                let $result :=
                    <node type="element'" xml:id="{concat('uuid-', util:uuid())}" status="{$layer-1-status}">
                        <target type="element" layer="annotation">
                            <annotation-layer>
                                <id>{$layer-1-id}</id>
                                <order>{$i}</order>
                            </annotation-layer>
                        </target>
                        <body>{$element}</body>
                    </node>
                    return
                        if (not($result//body/string()) or $result//body/*/node() instance of text() or $result//body/node() instance of text())
                        then $result 
                        else local:whittle-down-annotations($result)
};

declare function local:handle-mixed-content-annotations($node as node()) as item()* {
    (:Basically, an annotation with mixed contents should be split up into text annotations and element annotations, in the same manner that the top-level annotations were extracted from the input:)
            let $layer-1-body-contents := $node//body/*(:get element below body - this can ony be a single element:)
            let $layer-1-body-contents := element {node-name($layer-1-body-contents)}{
                for $attribute in $layer-1-body-contents/@*
                    return attribute {name($attribute)} {$attribute}} (:construct empty element with attributes:)
            let $layer-1 := local:remove-elements($node, 'body')(:remove the body,:)
            let $layer-1 := local:insert-element($layer-1, <body>{$layer-1-body-contents}</body>, 'target', 'after')(:and insert the new body:)
                return $layer-1
            ,
            let $layer-2-body-contents := local:get-top-level-nodes-base-layer($node//body/*, '')
            let $layer-1-id := <id>{$node/@xml:id/string()}</id>
            for $layer-2-body-content in $layer-2-body-contents
                return
                    let $layer-2-body-content := local:remove-elements($layer-2-body-content, ('id', 'layer-offset-difference'))
                    let $layer-2 := local:insert-element($layer-2-body-content, $layer-1-id, 'start', 'before')
                    let $log := util:log("DEBUG", ("##$layer-2): ", $layer-2))
                        return
                            if (not($layer-2//body/string()) or $layer-2//body/*/node() instance of text() or $layer-2//body/node() instance of text())
                        then $layer-2
                        else local:whittle-down-annotations($layer-2)
                            (:the layer attribute should be removed:)
};

declare function local:whittle-down-annotations($node as node()) as item()* {
            if (not($node//body/string())) (:no text node - an empty element - pass through:)
            then $node
            else 
                if ($node//body/*/node() instance of text()) (: one level until text node  - pass through - also filters away mixed contents:)
                then $node
                else 
                    if (count($node//body/*/*) eq 1 and $node//body/*/*[../text()]) (:mixed contents - send on and receive back - if there is an element (second *) and its parent (first *) is a text node, then we are dealing with mixed contents:)
                    then local:handle-mixed-content-annotations($node)
                    else local:handle-element-annotations($node) (:if it is not an empty element, if it is not exclusively a text node and if it is not mixed contents, then it is exclusively one or more element nodes - send on and receive back :)
};

let $input := <p xml:id="uuid-538a6e13-f88b-462c-a965-f523c3e02bbf">I <choice><reg>met</reg><sic>meet</sic></choice> <name ref="#SW" type="person"><forename><app><lem wit="#a">Steve</lem><rdg wit="#b">Stephen</rdg></app></forename> <surname>Winwood</surname></name> and <app><rdg wit="#base"><name ref="#AK" type="person">Alexis Korner</name></rdg><rdg wit="#c" ><name ref="#JM" type="person">John Mayall</name></rdg></app> <pb n="3"></pb>in <rs>the pub</rs><note resp="#JØP">The author is <emph>pro-<pb n="3"/>bably</emph> wrong here.</note>.</p>

let $base-text := string-join(local:separate-layers($input, 'base'))
    
let $authoritative-text := string-join(local:separate-layers($input, 'authoritative'))

let $edition-layer-elements := ('app', 'choice')

let $top-level-nodes-base-layer := <nodes>{local:get-top-level-nodes-base-layer($input, $edition-layer-elements)}</nodes>

let $top-level-nodes-base-and-authoritative-layer := local:insert-authoritative-layer($top-level-nodes-base-layer)

(: actually, we don't need the text nodes, so they can be left out above this. :)
(: We do actually need text nodes in the broken down annotations. :)
let $top-level-text-nodes := 
    for $node in $top-level-nodes-base-and-authoritative-layer
    return 
        if ($node/body/text() and not($node/body/element())) then $node else ()

let $annotations :=
    for $node in $top-level-nodes-base-and-authoritative-layer
        where $node/body/node() instance of element() (:filters away pure text nodes:)
    return 
        local:whittle-down-annotations($node)
        
        return 
            <result>
                <div type="input">{$input}</div>
                <div type="base-text">{$base-text}</div>
                <div type="authoritative-text">{$authoritative-text}</div>
                <div type="annotations">{$annotations}</div>
            </result>