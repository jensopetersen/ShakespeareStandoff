xquery version "3.0";

module namespace so2il="http://exist-db.org/xquery/app/standoff2inline";

import module namespace config="http://exist-db.org/apps/merula/config" at "config.xqm";
import module namespace il2so="http://exist-db.org/xquery/app/inline2standoff" at "../mopane/inline2standoff.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";

(: TODO :)
(: Separate header and text. :)
(: Multiple editorial targets must be made possible, not just the base text and one target text. This means that each feature annotation must be keyed to the target text it is based on.:)

(:values for $action: 'store', 'display':)(:NB: not used yet:)
(:values for $base: 'stored', 'generated':)(:NB: not used yet:)
(:values used for $target-format: 'tei', 'html':)
(: The $node is the node from the base text with the xml:id that is passed in the url :)
(: $target-format and $editiorial-element-names are fed from app.xql:)
(: NB: $editiorial-element-names should not be set in app.xql, but in some general place.:)
declare function so2il:standoff2inline($node as node()?, $editiorial-element-names as xs:string+, $target-format as xs:string) {
        
    (:Get the document's xml:id.:)
    let $doc := root($node)/*
    let $doc-id := $doc/@xml:id/string()
    (: Get the value for the witness defining the base text, app/(rdg | lem)[@wit eq $wit].:)
    (: NB: the value for the target text should be passed here as well, but for the time being it is simply app/lem.:)
    let $wit := $doc/tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:listWit/tei:witness[@n eq '1']/string()
    return
        so2il:annotate-text($node, $doc-id, $editiorial-element-names, $target-format, $wit)
};

declare function so2il:annotate-text($node as node()?, $doc-id as xs:string, $editiorial-element-names as xs:string+, $target-format as xs:string, $wit as xs:string?) {

    (:Recurse though the node.:)
    (: $node will here first be the node passed from so2il:standoff2inline(), that is the base text node called in the url, but will then recurse through it, annotating as it goes along. :)
    let $node := so2il:standoff2inline-recurser($node, $doc-id, $editiorial-element-names, $target-format, $wit)
    let $node-id := $node/@xml:id/string()
(:    let $log := util:log("DEBUG", ("##$node-id): ", $node-id)):)
    (:Get all annotations for the text block element in question. At first, only the top-level annotations are needed, but when the annotations are built up, all annotations need to be referenced. :)
    (: TODO: All annotations for a whole document are to be gathered here, since placing annotations in collections for each text block is probably not feasible. This would mean using
    let $annotations := collection(($config:a8ns) || "/" || $doc-id)/*
The present approach is however very handy when debugging. :)
    let $annotations := collection(($config:a8ns) || "/" || $doc-id || "/" || $node-id)/*
(:    let $log := util:log("DEBUG", ("##$annotations): ", $annotations)):)
    (:Get all top-level edition annotations for the base text element in question, that is, all editorial annotations that target its id. :)
    let $top-level-edition-a8ns := 
            if ($annotations)
            then $annotations[a8n-target/a8n-offset][a8n-body/*/local-name() = $editiorial-element-names][a8n-target/a8n-id eq $node/@xml:id]
            else ()
(:    let $log := util:log("DEBUG", ("##$top-level-edition-a8ns): ", $top-level-edition-a8ns)):)
    
    (:Build up the top-level edition annotations, that is, insert annotations that reference the top-level edition annotations, recursing until the whole annotation is assembled. The built-up annotation at this stage consist of nested a8n-annotation elements, where an annotation (an attribute or a child element) that refers to another annotation is inserted into the body of the annotation in question, that is, following the element that the annotation consists of. :)
    let $built-up-edition-a8ns := 
        if ($top-level-edition-a8ns) 
        then so2il:build-up-annotations($top-level-edition-a8ns, $annotations)
        else ()
(:    let $log := util:log("DEBUG", ("##$built-up-edition-a8ns): ", $built-up-edition-a8ns)):)
    
    (:Collapse the nested built-up editorial annotations, that is, prepare them for insertion into the base text
    by removing all elements except the contents of body and attaching attributes, that is, reconstituting the elements as TEI elements below a8n-target.:)
    let $collapsed-edition-a8ns := 
        if ($built-up-edition-a8ns) 
        then so2il:collapse-annotations($built-up-edition-a8ns)
        else ()
(:    let $log := util:log("DEBUG", ("##$collapsed-edition-a8ns): ", $collapsed-edition-a8ns)):)
(:    Order the collapsed editorial annotations according to offset and range. :)

    let $collapsed-edition-a8ns := 
        for $collapsed-edition-a8n in $collapsed-edition-a8ns
        order by 
            sum($collapsed-edition-a8n/a8n-target/a8n-offset) ascending,
            number($collapsed-edition-a8n/a8n-target/a8n-order) ascending, 
            number($collapsed-edition-a8n/a8n-target/a8n-range) descending
        return $collapsed-edition-a8n
(:    let $log := util:log("DEBUG", ("##$collapsed-edition-a8ns): ", $collapsed-edition-a8ns)):)
    
    (:Insert the collapsed annotations into the base-text.:)
    let $base-text-with-merged-edition-a8ns := 
        if ($collapsed-edition-a8ns) 
        then so2il:merge-annotations-with-text($node, $collapsed-edition-a8ns, 'edition', 'tei', $wit, $editiorial-element-names)
        else $node
    (:Result: base text with edition annotations inserted.:)
    (:TODO: Transform to show the target text with edition annotations inserted; use this a basis for generating target text?:)
(:    let $log := util:log("DEBUG", ("##$base-text-with-merged-edition-a8ns): ", $base-text-with-merged-edition-a8ns)):)
    
    (:On the basis of the inserted edition annotations, contruct the target text.:)
    (:TODO: Into the $base-text-with-merged-edition-a8ns, spans identifying the edition annotations should be inserted, 
    in order to provide hooks to these annotations in the HTML. 
    Resurrect mopane code for layer-range-difference and merge both edition and feature annotation with target text.:)  
    (:TODO: Make it possible for the whole text node to be wrapped up in an (inline) element.:)
    let $target-text := 
        if ($base-text-with-merged-edition-a8ns)
        then so2il:tei2target($base-text-with-merged-edition-a8ns, 'target-text', $wit)
        else $base-text-with-merged-edition-a8ns
(:    let $log := util:log("DEBUG", ("##$target-text): ", $target-text)):)

    (:Get the top-level feature annotations for the element in question, that is, 
    the feature annotations that connect to the target text though text ranges.:)
    let $top-level-feature-a8ns := 
        if ($annotations)
        then $annotations[a8n-target/a8n-offset][not(a8n-body/*/local-name() = ($editiorial-element-names))][a8n-target/a8n-id eq $node/@xml:id]
        else ()
(:    let $log := util:log("DEBUG", ("##$top-level-feature-a8ns): ", $top-level-feature-a8ns)):)
    
    (:Build up the top-level feature annotations, that is, 
    insert annotations that reference the top-level feature annotations recursively into the top-level feature annotations.:)
    let $built-up-feature-a8ns := 
        if ($top-level-feature-a8ns) 
        then so2il:build-up-annotations($top-level-feature-a8ns, $annotations)
        else ()
(:    let $log := util:log("DEBUG", ("##$built-up-feature-a8ns): ", $built-up-feature-a8ns)):)
    
    (:Collapse the built-up feature annotations, that is, prepare them for insertion into the target text
    by removing all elements except the contents of body.:) 
    let $collapsed-feature-a8ns := 
        if ($built-up-feature-a8ns) 
        then so2il:collapse-annotations($built-up-feature-a8ns)
        else ()
(:    let $log := util:log("DEBUG", ("##$collapsed-feature-a8ns-1): ", $collapsed-feature-a8ns)):)
    let $collapsed-feature-a8ns := 
        for $collapsed-feature-a8n in $collapsed-feature-a8ns
        order by
            sum($collapsed-feature-a8n/a8n-target/a8n-offset) ascending, 
            number($collapsed-feature-a8n/a8n-target/a8n-order) ascending, 
            number($collapsed-feature-a8n/a8n-target/a8n-range) descending
        return $collapsed-feature-a8n
(:    let $log := util:log("DEBUG", ("##$collapsed-feature-a8ns-2): ", $collapsed-feature-a8ns)):)
    
    (:Insert the collapsed annotations into the target text, producing a marked-up TEI document.:)
    let $target-text-with-merged-feature-a8ns := 
        if ($collapsed-feature-a8ns) 
        then so2il:merge-annotations-with-text($target-text, $collapsed-feature-a8ns, 'feature', $target-format, $wit, $editiorial-element-names)
        else $node
    (: NB: if there are no a8ns, the base text is shown:)
    let $log := util:log("DEBUG", ("##$target-text-with-merged-feature-a8ns): ", $target-text-with-merged-feature-a8ns))
    
    (:Convert the TEI document to HTML: text block elements become divs and inline element become spans.:)
    let $block-element-names := ('ab', 'castItem', 'l', 'role', 'roleDesc', 'speaker', 'stage', 'p', 'quote')
    let $element-only-element-names := ('TEI', 'abstract', 'additional', 'address', 'adminInfo', 'altGrp', 'altIdentifier', 'alternate', 'analytic', 'app', 'appInfo', 'application', 'arc', 'argument', 'attDef', 'attList', 'availability', 'back', 'biblFull', 'biblStruct', 'bicond', 'binding', 'bindingDesc', 'body', 'broadcast', 'cRefPattern', 'calendar', 'calendarDesc', 'castGroup', 'castList', 'category', 'certainty', 'char', 'charDecl', 'charProp', 'choice', 'cit', 'classDecl', 'classSpec', 'classes', 'climate', 'cond', 'constraintSpec', 'correction', 'correspAction', 'correspContext', 'correspDesc', 'custodialHist', 'datatype', 'decoDesc', 'dimensions', 'div', 'div1', 'div2', 'div3', 'div4', 'div5', 'div6', 'div7', 'divGen', 'docTitle', 'eLeaf', 'eTree', 'editionStmt', 'editorialDecl', 'elementSpec', 'encodingDesc', 'entry', 'epigraph', 'epilogue', 'equipment', 'event', 'exemplum', 'fDecl', 'fLib', 'facsimile', 'figure', 'fileDesc', 'floatingText', 'forest', 'front', 'fs', 'fsConstraints', 'fsDecl', 'fsdDecl', 'fvLib', 'gap', 'glyph', 'graph', 'graphic', 'group', 'handDesc', 'handNotes', 'history', 'hom', 'hyphenation', 'iNode', 'if', 'imprint', 'incident', 'index', 'interpGrp', 'interpretation', 'join', 'joinGrp', 'keywords', 'kinesic', 'langKnowledge', 'langUsage', 'layoutDesc', 'leaf', 'lg', 'linkGrp', 'list', 'listApp', 'listBibl', 'listChange', 'listEvent', 'listForest', 'listNym', 'listOrg', 'listPerson', 'listPlace', 'listPrefixDef', 'listRef', 'listRelation', 'listTranspose', 'listWit', 'location', 'locusGrp', 'macroSpec', 'media', 'metDecl', 'moduleRef', 'moduleSpec', 'monogr', 'msContents', 'msDesc', 'msIdentifier', 'msItem', 'msItemStruct', 'msPart', 'namespace', 'node', 'normalization', 'notatedMusic', 'notesStmt', 'nym', 'objectDesc', 'org', 'particDesc', 'performance', 'person', 'personGrp', 'physDesc', 'place', 'population', 'postscript', 'precision', 'prefixDef', 'profileDesc', 'projectDesc', 'prologue', 'publicationStmt', 'punctuation', 'quotation', 'rdgGrp', 'recordHist', 'recording', 'recordingStmt', 'refsDecl', 'relatedItem', 'relation', 'remarks', 'respStmt', 'respons', 'revisionDesc', 'root', 'row', 'samplingDecl', 'schemaSpec', 'scriptDesc', 'scriptStmt', 'seal', 'sealDesc', 'segmentation', 'sequence', 'seriesStmt', 'set', 'setting', 'settingDesc', 'sourceDesc', 'sourceDoc', 'sp', 'spGrp', 'space', 'spanGrp', 'specGrp', 'specList', 'state', 'stdVals', 'styleDefDecl', 'subst', 'substJoin', 'superEntry', 'supportDesc', 'surface', 'surfaceGrp', 'table', 'tagsDecl', 'taxonomy', 'teiCorpus', 'teiHeader', 'terrain', 'text', 'textClass', 'textDesc', 'timeline', 'titlePage', 'titleStmt', 'trait', 'transpose', 'tree', 'triangle', 'typeDesc', 'vAlt', 'vColl', 'vDefault', 'vLabel', 'vMerge', 'vNot', 'vRange', 'valItem', 'valList', 'vocal')

    let $html := so2il:tei2html($target-text-with-merged-feature-a8ns, $block-element-names, $element-only-element-names)
(:    let $log := util:log("DEBUG", ("##$html): ", $html)):)
    
    return
        $html
};

declare function so2il:generate-target-text($input as node()*) as item()* {
        for $node in $input/node()
        return
            typeswitch($node)
                case element(tei:note) return ()
                case element(tei:lem) return so2il:generate-target-text($node)
                case element(tei:rdg) return ()
                case element(tei:corr) return so2il:generate-target-text($node)
                case element(tei:sic) return ()
                case element(tei:expan) return so2il:generate-target-text($node)
                case element(tei:abbr) return ()
                case element(tei:reg) return so2il:generate-target-text($node)
                case element(tei:orig) return ()
                case text() return $node
                default return so2il:generate-target-text($node)
};

declare function so2il:tei2target($node as node()*, $target-layer as xs:string, $wit as xs:string?) {
        (:If the element has a text node, separate the text node.:)
        (:TODO: Make it possible for the whole text node to be wrapped up in an (inline) element.:)
        element {node-name($node)}{$node/@*,so2il:generate-target-text($node)}
        
};

(:Convert TEI text block elements into divs and inline elements into spans.:)
(:For reasons of simplicity, te usual way of converting TEI into "quasi-semantic" HTML is avoided.:)
declare function so2il:tei2html($node as node(), $block-element-names as xs:string+, $element-only-element-names as xs:string+) {
    element {if (local-name($node) = ($block-element-names, $element-only-element-names)) then 'div' else 'span'}
        {$node/@*, attribute {'class'}{local-name($node)}, attribute {'title'}{if ($node/@type) then concat($node/@type, '-', local-name($node)) else local-name($node)}
        ,
        for $child in $node/node()
        return
            if ($child instance of element() and not($child/@class))
            (:NB: Check! Class attributes come from above in the same function, so elements will have more than one @class attached.:)
            then so2il:tei2html($child, $block-element-names, $element-only-element-names)
            else $child
        }
};

declare function so2il:standoff2inline-recurser($node as node(), $doc-id as xs:string, $editiorial-element-names as xs:string+, $target-format as xs:string, $wit as xs:string?) {
    element {node-name($node)}
        {$node/@*
        , 
        for $child in $node/node()
        return
            if ($child instance of element())
            then so2il:annotate-text($child, $doc-id, $editiorial-element-names, $target-format, $wit)
            else $child
        }
};

(:This function takes a sequence of top-level annotations and inserts as children all annotations that refer to them through their @xml:id, recursively:)
declare function so2il:build-up-annotations($parent-annotations as element()*, $annotations as element()*) as element()* {
    for $parent-annotation in $parent-annotations
    return
        so2il:build-up-annotation($parent-annotation, $annotations)
};

(:This function recursively inserts annotations into their parent annotations.:)
declare function so2il:build-up-annotation($parent-annotation as element(), $annotations as element()*) as element()* {
    let $parent-annotation-id := $parent-annotation/@xml:id/string()
    let $parent-annotation-element-name := local-name($parent-annotation/a8n-body/*)
    let $children := so2il:build-up-annotations($annotations[a8n-target/a8n-id eq $parent-annotation-id], $annotations)
    let $children := 
        for $child in $children
        order by $child/a8n-target/a8n-order
        return $child
    return
        il2so:insert-elements($parent-annotation, $children, $parent-annotation-element-name,  'first-child')
};

(:Recurser for so2il:collapse-annotation().:)
(:TODO: Clear up why so2il:collapse-annotation() has to be run three times.:) 
declare function so2il:collapse-annotations($built-up-edition-annotations as element()*) {
    for $annotation in $built-up-edition-annotations
(:    let $log := util:log("DEBUG", ("##$collapsed-annotation-0): ", $annotation)):)
    let $collapsed-annotation := so2il:collapse-annotation($annotation, 'a8n-annotation')
(:    let $log := util:log("DEBUG", ("##$collapsed-annotation-1): ", $collapsed-annotation)):)
    let $collapsed-annotation := so2il:collapse-annotation($collapsed-annotation, 'a8n-body')
(:    let $log := util:log("DEBUG", ("##$collapsed-annotation-2): ", $collapsed-annotation)):)
    return 
        $collapsed-annotation
(:        so2il:collapse-annotation(so2il:collapse-annotation($annotation, 'a8n-annotation'), 'a8n-body'):)
};

(: This function takes a built-up annotation and 
1) attaches attributes, stored as grandchildren,
2) collapses it, i.e. removes levels from the hierarchy by substituting elements with their children, 
3) removes unneeded elements, and 
4) takes the string values of terminal text-critical elements that have child feature annotations. :)
declare function so2il:collapse-annotation($element as element(), $strip as xs:string+) as element() {
(:    let $log := util:log("DEBUG", ("##$element): ", $element)) return:)
    element {node-name($element)}
    {$element/@*, 
        if ($element/*/*/a8n-attribute/*)
        then 
            for $attribute in $element/*/*/a8n-attribute
            return
                let $attribute-name := $attribute/a8n-name/string()
                let $attribute-value := $attribute/a8n-value/string()
                return
                    attribute {$attribute-name} {$attribute-value}
        else ()
        ,
        for $child in $element/node()
        return
            (:If the child is on the list of elements to be stripped, just bypass it and substitute its children.:)
            if ($child instance of element() and local-name($child) = $strip)
            then 
                for $child in $child/*
                return 
                    so2il:collapse-annotation(($child), $strip)
            else
                if ($child instance of element() and local-name($child) = ('a8n-attribute', 'a8n-layer-range-difference', 'a8n-target-layer')) (:we have no need for these two elements - actually, they have been removed, but should they be introduced again?:)
                then ()
                else
                    (:skip the attribute attached above:)
                    if ($child instance of element() and local-name($child) = 'a8n-target' and local-name($child/parent::element()) ne 'a8n-annotation') (:remove all target elements that are not at the base level:)
                    then ()
                    else
                        if ($child instance of element() and local-name($child/..) = ('lem', 'rdg', 'sic', 'reg') ) (:take string value of elements that are below terminal elements concerned with edition:)
                        then string-join($child//text(), ' ') (:NB: This is a hack (@token should be used) but in real life text-critical annotations will not have sibling children with text nodes, so this is only relevant to round-tripping with annotations that mix text-critical and feature annotations.:)
                        else
                            if ($child instance of text())
                            then $child
                            else so2il:collapse-annotation($child, $strip)
      }
};

(: Order the a8ns according to position and wraps up an a8n in <quarantine> if the following a8n has a non-nesting overlap relationship with it. :)
(: TODO: see that the quarantined a8ns are feed to a repetition of the text, outputting both the a8ns that were accepted and rejected. :)
declare function so2il:wrap-up-a8ns-with-non-nesting-overlap($a8ns as element()+) as element() {
let $a8ns := 
    <a8ns>{
        for $a8n in $a8ns
        let $a8n-offset := sum($a8n/a8n-target/a8n-offset)
        let $a8n-range := number($a8n/a8n-target/a8n-range)
        return
            if (
                $a8n/following-sibling::a8n-annotation
                [sum(a8n-target/a8n-offset) > $a8n-offset]
                [sum(a8n-target/a8n-offset) + number(a8n-target/a8n-range) > $a8n-offset + $a8n-range]
                [(sum(a8n-target/a8n-offset) - $a8n-offset) > (number(a8n-target/a8n-range) - $a8n-range)]
                [sum(a8n-target/a8n-offset) < $a8n-offset + $a8n-range]
                or
                $a8n/following-sibling::a8n-annotation
                [sum(a8n-target/a8n-offset) < $a8n-offset]
                [sum(a8n-target/a8n-offset) + number(a8n-target/a8n-range) < $a8n-offset + $a8n-range]
                [$a8n-offset + $a8n-range > $a8n-offset - sum(a8n-target/a8n-offset)]
                [sum(a8n-target/a8n-offset) + number(a8n-target/a8n-range) > $a8n-offset]
                )
            then <quarantine>{$a8n}</quarantine>
            else $a8n
}</a8ns>

return $a8ns
};


(: Orders a8ns according to range, descending, and collects all instances where an a8n contains one or more following a8ns. :)
(:NB: This puts empty elements inside an a8n that should follow it.:)
declare function so2il:wrap-up-contained-a8ns($a8ns as element()+) as element()* {
let $a8ns := 
    <a8ns>{$a8ns}</a8ns>
let $a8ns := 
    <a8ns>{
    for $a8n in $a8ns/*
    order by 
        number($a8n/a8n-target/a8n-range) descending, 
        sum($a8n/a8n-target/a8n-offset)
        return
            $a8n
    }</a8ns>
let $a8ns := 
    for $a8n in $a8ns/*
    let $a8n-offset := sum($a8n/a8n-target/a8n-offset)
    let $a8n-range := number($a8n/a8n-target/a8n-range)
    return
        if (
            $a8n/following-sibling::a8n-annotation
            [sum(a8n-target/a8n-offset) >= $a8n-offset]
            [number(a8n-target/a8n-range) <= $a8n-range - (sum(a8n-target/a8n-offset) - $a8n-offset)]
            [sum(a8n-target/a8n-offset) <= $a8n-offset + $a8n-range]
            )
        then <containment>
                <container>{$a8n}</container>
                <contained>
                    {
                    $a8n/following-sibling::a8n-annotation
                    [sum(a8n-target/a8n-offset) >= $a8n-offset]
                    [number(a8n-target/a8n-range) <= $a8n-range - (sum(a8n-target/a8n-offset) - $a8n-offset)]
                    [sum(a8n-target/a8n-offset) <= $a8n-offset + $a8n-range]
                    }
                </contained>
            </containment>
        else 
            if (
                $a8n/preceding-sibling::a8n-annotation
                [sum(a8n-target/a8n-offset) <= $a8n-offset]
                [number(a8n-target/a8n-range) >= $a8n-range - (sum(a8n-target/a8n-offset) - $a8n-offset)]
                [sum(a8n-target/a8n-offset) <= $a8n-offset + $a8n-range]
                )
            then ()
            else
                $a8n
let $a8ns := 
    for $a8n in $a8ns
    order by 
        sum($a8n/a8n-target/a8n-offset), 
        number($a8n/a8n-target/a8n-order), 
        number($a8n/a8n-target/a8n-range)
    return
        $a8n
return 
    $a8ns
};

declare function so2il:wrap-up-a8ns-with-identical-position($a8ns as element()+) as element()* {
let $a8ns := <a8ns>{$a8ns}</a8ns>
let $a8ns := 
    for $a8n in $a8ns/*
    return
        if
        (
        number($a8n/a8n-target/a8n-range) > 0 
        and
        $a8n/following-sibling::a8n-annotation[sum(a8n-target/a8n-offset) = sum($a8n/a8n-target/a8n-offset)][number(a8n-target/a8n-range) = number($a8n/a8n-target/a8n-range)]
        and
        not($a8n/preceding-sibling::a8n-annotation[sum(a8n-target/a8n-offset) = sum($a8n/a8n-target/a8n-offset)][number(a8n-target/a8n-range) = number($a8n/a8n-target/a8n-range)])
        )
        then <identical-position-cluster>{$a8n, $a8n/following-sibling::a8n-annotation[sum(a8n-target/a8n-offset) = sum($a8n/a8n-target/a8n-offset)][number(a8n-target/a8n-range) = number($a8n/a8n-target/a8n-range)]}</identical-position-cluster>
        else 
            if (number($a8n/a8n-target/a8n-range) = 0 )
            then $a8n
            else
                if (
                ($a8n/preceding-sibling::a8n-annotation[sum(a8n-target/a8n-offset) = sum($a8n/a8n-target/a8n-offset)] and
                $a8n/preceding-sibling::a8n-annotation[number(a8n-target/a8n-range) = number($a8n/a8n-target/a8n-range)]
                or
                ($a8n/following-sibling::a8n-annotation[sum(a8n-target/a8n-offset) = sum($a8n/a8n-target/a8n-offset)] and $a8n/following-sibling::a8n-annotation[number(a8n-target/a8n-range) = number($a8n/a8n-target/a8n-range)])
                ))
                then ()
                else $a8n
return 
    $a8ns
};

(:~
: @author Jens Erat
: @param 
: @param 
: @return 
: @see https://stackoverflow.com/questions/33186967
:)
declare function so2il:wrap-up-elements($elements as element()+) as element()+ {
  let $head := head($elements)
  let $tail := tail($elements)
  return
    element { name($head) } { (
      $head/@*,
      $head/node(),
      if ($tail)
      then so2il:wrap-up-elements($tail)
      else ()
    ) }
};

(:This function merges the collapsed annotations with the target text. 
A sequence of slots (<slot/>s), double the number of annotations plus 1, are created; 
annotations are filled into the even slots, whereas the text, 
with ranges calculated from the previous and following annotations, 
are filled into the uneven slots. Empty uneven slots can occur, 
but all even slots have annotations (though they may consist of an empty element).:)
(:TODO: check annotations for superimposition, containment, overlap. Use parent element and preceding-sibling nodes to get the correct hierarchical and sequential order:)
declare function so2il:merge-annotations-with-text($text-element as element(), $annotations as element()*, $target-layer as xs:string, $target-format as xs:string, $wit as xs:string, $editiorial-element-names as xs:string+) as node()+ {
    let $annotations := so2il:wrap-up-a8ns-with-non-nesting-overlap($annotations)
    let $annotations := $annotations/(* except quarantine)
(:    let $annotations := :)
(:        if ($target-layer eq 'feature'):)
(:        then so2il:wrap-up-a8ns-with-identical-position($annotations):)
(:        else $annotations:)
    let $annotations := 
        if ($target-layer eq 'feature')
        then so2il:wrap-up-contained-a8ns($annotations)
        else $annotations
    let $annotations := 
        for $annotation in $annotations
        let $offset := 
            if ($annotation//container)
            then sum($annotation//container/a8n-annotation/a8n-target/a8n-offset)
            else 
                if (local-name($annotation) eq 'identical-position-cluster')
                then sum($annotation/a8n-annotation[1]/a8n-target/a8n-offset)
                else sum($annotation/a8n-target/a8n-offset)
        let $order := 
            if ($annotation//container)
            then number($annotation//container/a8n-annotation/a8n-target/a8n-order)
            else 
                if (local-name($annotation) eq 'identical-position-cluster')
                then number($annotation/a8n-annotation[1]/a8n-target/a8n-order)
                else number($annotation/a8n-target/a8n-order)
        let $range := 
            if ($annotation//container)
            then number($annotation//container/a8n-annotation/a8n-target/a8n-range)
            else 
                if (local-name($annotation) eq 'identical-position-cluster')
                then number($annotation/a8n-annotation[1]/a8n-target/a8n-range)
                else number($annotation/a8n-target/a8n-range)
        order by $offset, $order, $range
        return $annotation
    let $text-string := 
        if ($target-layer eq 'edition')
        then il2so:generate-base-text($text-element, $wit)
        else so2il:generate-target-text($text-element)
    let $slot-count := (count($annotations) * 2) + 1
    let $slots :=
        for $slot at $i in 1 to $slot-count
        return
            <slot n="{$i}"/>
    let $slots := 
            for $slot in $slots
            return
                if (number($slot/@n) mod 2 eq 0) (:An annotation is being processed.:)
                then
                    let $annotation-n := number($slot/@n) div 2
                    let $annotation := $annotations[$annotation-n]
                    let $annotation := 
                        (: we are dealing with a cluster of a8ns with identical position:)
                        if (local-name($annotation) eq 'identical-position-cluster')
                        then
                            let $cluster := $annotation/*
                            let $cluster := 
                                for $annotation in $cluster
                                order by $annotation/a8n-target/a8n-order descending
                                return
                                    $annotation
                            let $inner-element := $cluster[1]
                            let $inner-element-id := string($inner-element/@xml:id)
                            let $offset := sum($inner-element/a8n-target/a8n-offset)
                            let $range := number($inner-element/a8n-target/a8n-range)
                            let $inner-element := $inner-element/(* except a8n-target)
                            let $inner-element := 
                                element{node-name($inner-element)}{$inner-element/@*, (attribute{'a8n-id'}{$inner-element-id}), substring($text-string, $offset, $range)}
                            let $outer-elements := $cluster[position() > 1]
                            let $outer-elements := 
                                for $outer-element in $outer-elements
                                let $outer-element-id := string($outer-element/@xml:id)
                                let $outer-element := $outer-element/(* except a8n-target)
(:                                let $outer-element := :)
(:                                    element{node-name($inner-element)}{$inner-element/@*, (attribute{'a8n-id'}{$outer-element-id}), substring($text-string, $offset, $range)}:)
                                return
                                    $outer-element
                            let $wrapped := so2il:wrap-up-elements(($outer-elements, $inner-element))
                            return
                                $wrapped
                        else
                        (: if we are dealing with a case of containment, treat the container as the text element and apply the contained a8ns to it as if they were top level a8ns. :)
                            if ($annotation//container)
                            then
                                let $container-annotation := $annotation//container/a8n-annotation
                                let $contained-annotations := 
                                    for $annotation in $annotation//contained/a8n-annotation
                                    order by 
                                        sum($annotation/a8n-target/a8n-offset), 
                                        number($annotation/a8n-target/a8n-order), 
                                        number($annotation/a8n-target/a8n-range)
                                    return $annotation
                                (: modify the offset of the contained a8ns by inserting an offset subtracting the container offset. :)
                                let $contained-annotations := 
                                    for $contained-annotation in $contained-annotations
                                    let $version-difference := <a8n-offset>{-sum($container-annotation/a8n-target[1]/a8n-offset) + 1}</a8n-offset>
                                    return
                                        il2so:insert-elements($contained-annotation, $version-difference, 'a8n-offset', 'after')
                                return
                                    let $annotation-offset := sum($container-annotation/a8n-target/a8n-offset)
                                    let $annotation-range := number($container-annotation/a8n-target/a8n-range)
                                    let $a8n-id := string($annotation/@xml:id)
                                    let $annotation := $container-annotation/(* except a8n-target)
                                    let $result :=
                                        element {node-name($annotation)}{$annotation/@*, (attribute{'a8n-id'}{$a8n-id}), substring($text-string, $annotation-offset, $annotation-range)}
                                    let $result := 
                                        so2il:merge-annotations-with-text($result, $contained-annotations, $target-layer, $target-format, $wit, $editiorial-element-names)
                                    return
                                        $result
                            else
                                (: if we are dealing with a simple offset and range annotation which does not have element children, :)
                                if (not($annotation/(* except a8n-target)/element()))
                                (: get the element text contents from the constructed text version, :)
                                then 
                                    let $annotation-offset := sum($annotation/a8n-target/a8n-offset)
                                    let $annotation-range :=  number($annotation/a8n-target/a8n-range)
                                    let $a8n-id := string($annotation/@xml:id)
                                    let $annotation := $annotation/(* except a8n-target)
                                    return
                                        element {node-name($annotation)}{$annotation/@*, (attribute{'a8n-id'}{$a8n-id}), substring($text-string, $annotation-offset, $annotation-range)}
                                (: otherwise, if there is element contents, just pass on the annotation. :)
                                (: in pracice, these a8ns will all be editorial:)
                                else 
                                    let $a8n-id := string($annotation/@xml:id)
                                    let $annotation := $annotation/(* except a8n-target)
                                    return
                                    element {node-name($annotation)}{$annotation/@*, (attribute{'a8n-id'}{$a8n-id}), $annotation/node()}
                                    
                        return
                            il2so:insert-elements($slot, $annotation, 'slot', 'first-child')
                (: A text node is being processed.:)
                else
                    <slot n="{$slot/@n/string()}">
                        {
                        let $slot-n := number($slot/@n)
                        let $previous-annotation-n := ($slot-n - 1) div 2
                        let $previous-annotation := $annotations[$previous-annotation-n]
                        let $previous-annotation := 
                            if ($previous-annotation//container)
                            then $previous-annotation//container/a8n-annotation
                            else $previous-annotation
                        let $following-annotation-n := ($slot-n + 1) div 2
                        let $following-annotation := $annotations[$following-annotation-n]
                        let $following-annotation := 
                            if ($following-annotation//container)
                            then $following-annotation//container/a8n-annotation
                            else $following-annotation
                        (: where does the text string that goes into the slot start? :)
                        let $offset := 
                            if (number($slot/@n) eq 1) (:if it is the first text node, the offset is 1:)
                            then 1
                            else 
                                (: otherwise, the text node starts where the previous a8n ends. :)
                                sum($previous-annotation/a8n-target/a8n-offset)
                                +
                                number($previous-annotation/a8n-target/a8n-range)
                                (:if it is not the first or last text node, 
                                the offset is the position of the previous annotation plus its range plus 1:)
                        (: how long the text string that goes into the slot? :)
                        let $range := 
                            (:if it is the last text node, the range is the length of the base text minus the end position of the last annotation plus 1:)
                            if ($slot-n eq count($slots))
                            then 
                                string-length($text-element)
                                -
                                (
                                    sum($previous-annotation/a8n-target/a8n-offset)
                                    +
                                    number($previous-annotation/a8n-target/a8n-range)
                                )
                                +
                                1
                            else
                                (:if it is the first text node, the the range is the offset of the following annotation minus 1:)
                                if ($slot-n eq 1)
                                then sum($following-annotation/a8n-target/a8n-offset) - 1
                                else sum($following-annotation/a8n-target/a8n-offset)
                                -
                                    (
                                        sum($previous-annotation/a8n-target/a8n-offset)
                                        +
                                        number($previous-annotation/a8n-target/a8n-range)
                                    )
                                (:if it is not the first or the last text node, then the range is the offset of the following annotation minus the end position of the previous annotation :)
                        return
                            if (number($offset) and number($range))
                            then substring($text-element, $offset, $range)
                            else ''
                        }
                    </slot>
    let $slots :=
        for $slot in $slots
        return
            if ($slot/@n mod 2 eq 0)
            then $slot/*
            else $slot/string()
    return 
        element {node-name($text-element)}{$text-element/@*, $slots}
};