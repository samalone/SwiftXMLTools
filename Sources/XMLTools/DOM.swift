import Foundation

public class Node {
    let parentNode: Node?
    
    public var childNodes = [Node]()
    
    init(parent: Node?) {
        self.parentNode = parent
    }
    
    public func name() -> QName? {
        return nil
    }
    
    public func parentDocument() -> Document? {
        var node: Node? = self
        while node != nil {
            if let doc = node as? Document {
                return doc
            }
            node = node?.parentNode
        }
        return nil
    }
    
    public func clone() -> Node {
        return Node(parent: nil)
    }
    
    public func clone(parent: Node) -> Node {
        return Node(parent: parent)
    }
    
    public func sanityCheck() {
        for n in childNodes {
            assert(n.parentNode === self)
            n.sanityCheck()
        }
    }
}

public class NamedNode: Node {
    let nodeName: QName
    
    internal init (name: QName) {
        self.nodeName = name
        super.init(parent: nil)
    }
    
    internal init (parent: Node, name: QName) {
        self.nodeName = name
        super.init(parent: parent)
    }
    
    public override func name() -> QName {
        return nodeName
    }
    
    public override func clone() -> NamedNode {
        return NamedNode(name: nodeName)
    }
    
    public override func clone(parent: Node) -> NamedNode {
        return NamedNode(parent: parent, name: nodeName)
    }
    
}

public class Attribute: NamedNode {
    public let value: String?
    
    override init (parent: Node, name: QName) {
        self.value = nil
        super.init(parent: parent, name: name)
    }
    init (parent: Node, name: QName, value: String) {
        self.value = value
        super.init(parent: parent, name: name)
    }
    
    init (parent: Node, from: Attribute) {
        self.value = from.value
        super.init(parent: parent, name: from.nodeName)
    }
    
    init (from: Attribute) {
        self.value = from.value
        super.init(name: from.nodeName)
    }
    
    public override func clone() -> Attribute {
        return Attribute(from: self)
    }
    
    public override func clone(parent: Node) -> Attribute {
        return Attribute(parent: parent, from: self)
    }
    
}

public class Element: NamedNode {
    public lazy var attributes = [QName: Attribute]()
    // all `xmlns` declarations as parsed from the source document
    internal var sourceNamespaceContext: NamespaceContext?
    // namespace context of the current document
    public var namespaceContext: NamespaceContext?

    @discardableResult
    public func appendElement(_ name: String) -> Element {
        return appendElement(QName(name))
    }
    
    @discardableResult
    public func appendElement(_ name: QName) -> Element {
        let element = Element(parent: self, name: name)
        childNodes.append(element)
        return element
    }
    
    @discardableResult
    public func appendAttribute(_ name: String, withValue value: String) -> Attribute {
        return appendAttribute(QName(name), withValue: value)
    }
    
    @discardableResult
    public func appendAttribute(_ name: String, withNamespace namespaceURI: String, andValue value: String) -> Attribute {
        return appendAttribute(QName(name, uri: namespaceURI), withValue: value)
    }
    
    @discardableResult
    public func appendAttribute(_ name: QName, withValue value: String) -> Attribute {
        let attr = Attribute(parent: self, name: name, value: value)
        attributes[attr.nodeName] = attr
        return attr
    }
    
    @discardableResult
    public func appendAttribute(_ name: QName) -> Attribute {
        let attr = Attribute(parent: self, name: name)
        attributes[attr.nodeName] = attr
        return attr
    }
    
    @discardableResult
    public func appendText(_ text: String) -> TextNode {
        let node = TextNode(parent: self, value: text)
        childNodes.append(node)
        return node
    }
    
    public func resolveURI(forPrefix prefix: String ) -> String? {
        var element: Element? = self
        while element != nil {
            if let uri = element?.namespaceContext?[prefix] {
                return uri
            }
            element = element?.parentNode as? Element
        }
        return nil
    }

    public func resolvePrefix(forURI uri: String) -> String? {
        var element: Element? = self
        while element != nil {
            if let uri = element?.namespaceContext?.resolvePrefix(forURI: uri) {
                return uri
            }
            element = element?.parentNode as? Element
        }
        return nil
    }
    
    func resolveURIFromSource(forPrefix prefix: String ) -> String? {
        var element: Element? = self
        while element != nil {
        if let uri = element?.sourceNamespaceContext?[prefix] {
            return uri
        }
            element = element?.parentNode as? Element
        }
        return nil
    }

    func resolvePrefixFromSource(forURI uri: String ) -> String? {
        var element: Element? = self
        while element != nil {
            if let uri = element?.sourceNamespaceContext?.resolvePrefix(forURI: uri) {
                return uri
            }
            element = element?.parentNode as? Element
        }
        return nil
    }
    
    public override func clone() -> Element {
        let copy = Element(name: nodeName)
        for a in attributes {
            copy.attributes[a.key] = a.value.clone(parent: copy)
        }
        for n in childNodes {
            copy.childNodes.append(n.clone(parent: copy))
        }
        return copy
    }
    
    public override func clone(parent: Node) -> Element {
        let copy = Element(parent: parent, name: nodeName)
        for a in attributes {
            copy.attributes[a.key] = a.value.clone(parent: copy)
        }
        for n in childNodes {
            copy.childNodes.append(n.clone(parent: copy))
        }
        return copy
    }
}

public class TextNode: Node {
    public let value: String
    
    init (parent: Node, value: String) {
        self.value = value
        super.init(parent: parent)
    }
    
    public override func clone(parent: Node) -> TextNode {
        return TextNode(parent: parent, value: value)
    }
    
}

public class CommentNode: Node {
    public let value: String
    
    init (parent: Node, value: String) {
        self.value = value
        super.init(parent: parent)
    }
    
    public override func clone(parent: Node) -> CommentNode {
        return CommentNode(parent: parent, value: value)
    }
    
}

public class CDATANode: TextNode {
    
    public override func clone(parent: Node) -> CDATANode {
        return CDATANode(parent: parent, value: value)
    }
    
}

public class ProcessingInstruction: Node {
    let target: String
    let data: String
    
    init (parent: Node, target: String, data: String) {
        self.target = target
        self.data = data
        super.init(parent: parent)
    }
    
    public override func clone(parent: Node) -> ProcessingInstruction {
        return ProcessingInstruction(parent: parent, target: target, data: data)
    }
}

public class Document: Node {
    // only support XML 1.0
    let version = "1.0"
    // only support UTF-8
    let encoding = String.Encoding.utf8
    // Document is not standalone by default
    var standalone = false

    var documentElement: Element?
    
    public init () {
        super.init(parent: nil)
    }
    
    @discardableResult
    public func appendElement(_ name: String) -> Element {
        return appendElement(QName(name))
    }
    
    public func appendElement(_ name: QName) -> Element {
        childNodes.removeAll()
        let element = Element(parent: self, name: name)
        element.namespaceContext = .defaultContext
        childNodes.append(element)
        documentElement = element
        return element
    }
    
    // the namespace context of the document is the one of it's root element
    public var namespaceContext: NamespaceContext {
        get {
            if let root = documentElement {
                if root.namespaceContext == nil {
                    root.namespaceContext = .defaultContext
                }
                return root.namespaceContext!
            } else {
                return .defaultContext
            }
        }
        set (context) {
            documentElement?.namespaceContext = context
        }
    }
        
}
