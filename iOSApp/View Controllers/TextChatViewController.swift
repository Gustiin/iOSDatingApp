//
//  TextChatViewController.swift
//  FirebaseAuthentification
//
//  Created by Eric Gustin on 5/15/20.
//  Copyright © 2020 Eric Gustin. All rights reserved.
//

import UIKit
import Firebase
import MessageKit
import FirebaseFirestore
import InputBarAccessoryView
import FirebaseAuth

final class TextChatViewController: MessagesViewController {
  
  private let db = Firestore.firestore()
  private var reference: CollectionReference? // reference to database
  
  private let user: User
  private var messages: [Message] = []
  private var messageListener: ListenerRegistration?
  
  init(user: User) {
    self.user = user
    super.init(nibName: nil, bundle: nil)
    title = "Time left"
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    messageListener?.remove()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.becomeFirstResponder()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let navBar = UINavigationBar(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 44))
    view.addSubview(navBar)
    
    let navItem = UINavigationItem(title: "Messages")
    let backItem = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: #selector(backToHome))
    navItem.rightBarButtonItem = backItem
    navBar.setItems([navItem], animated: false)
    
    let aChatRoomID = UUID().uuidString
    let aConversationID = UUID().uuidString
    reference = db.collection(["activeChatRooms", aChatRoomID, aConversationID].joined(separator: "/"))
    reference?.parent!.setData([
      "isFull": false,
      "person0uid": "\(user.uid)",
      "person1uid": ""
    ]) { err in
      if let err = err {
        print("Error adding document: \(err)")
      }
    }

    // the chat's id is ref!.documentID
    messageListener = reference?.addSnapshotListener({ (querySnapshot, error) in
      guard let snapshot = querySnapshot else {
        print("Error when listening for channel updates \(error?.localizedDescription ?? "No error")")
        return
      }
      snapshot.documentChanges.forEach { change in
        self.handleDocumentChange(change)
      }
    })
    
    navigationItem.largeTitleDisplayMode = .never
    
    maintainPositionOnKeyboardFrameChanged = true
    messageInputBar.inputTextView.tintColor = .systemBlue
    messageInputBar.sendButton.setTitleColor(.systemBlue, for: .normal)
    
    messageInputBar.delegate = self
    messagesCollectionView.messagesDataSource = self
    messagesCollectionView.messagesLayoutDelegate = self
    messagesCollectionView.messagesDisplayDelegate = self
    
//    print(messagesCollectionView.frame.height)
//    messagesCollectionView.translatesAutoresizingMaskIntoConstraints = false
//    messagesCollectionView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 20).isActive = true
//    print(messagesCollectionView.frame.height)
    
    let whiteColor = UIColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 1.0)
    view.backgroundColor = whiteColor
  }
  
  
  // MARK: - Actions
  @objc func backToHome() {
    //    let homeViewController = storyboard?.instantiateViewController(identifier: Constants.Storyboard.homeViewController) as? HomeViewController
    //    // Make profile ViewController appear fullscrean
    //    view.window?.rootViewController = homeViewController
    //    view.window?.makeKeyAndVisible()
    dismiss(animated: true, completion: nil)
  }
  
  // MARK: - Helpers
  
  private func save(_ message: Message) {
    reference?.addDocument(data: message.representation) { error in
      if let e = error {
        print("Error sending message: \(e.localizedDescription)")
        return
      }
      
      self.messagesCollectionView.scrollToBottom()
    }
  }
  
  private func insertNewMessage(_ message: Message) {
    guard !messages.contains(message) else {
      return
    }
    messages.append(message)
    messages.sort()
    
    let isLatestMessage = messages.firstIndex(of: message) == (messages.count - 1)
    let shouldScrollToBottom = isLatestMessage // && messagesCollectionView.isAtBottom
    messagesCollectionView.reloadData()
    
    if shouldScrollToBottom {
      DispatchQueue.main.async {
        self.messagesCollectionView.scrollToBottom(animated: true)
      }
    }
  }
  
  private func handleDocumentChange(_ change: DocumentChange) {
    guard let message = Message(document: change.document) else {
      return
    }
    print(change.type)
    switch change.type {
      case .added:
        insertNewMessage(message)
      default: break
    }
  }
}

// MARK: - MessagesDataSource

extension TextChatViewController: MessagesDataSource {
  // 1
  func currentSender() -> SenderType {
    var displayName: String = ""
    db.collection("users").document(user.uid).getDocument { (snapshot, error) in
    if let document = snapshot {
      displayName = document.get("firstName") as! String
      }
    }
    return Sender(senderId: user.uid, displayName: displayName)
  }
  
  // 2
  func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
    return messages.count
  }
  
  // 3
  func messageForItem(at indexPath: IndexPath,
                      in messagesCollectionView: MessagesCollectionView) -> MessageType {
    return messages[indexPath.section]
  }
  
  // 4
  func cellTopLabelAttributedText(for message: MessageType,
                                  at indexPath: IndexPath) -> NSAttributedString? {
    let name = message.sender.displayName
    return NSAttributedString(
      string: name,
      attributes: [
        .font: UIFont.preferredFont(forTextStyle: .caption1),
        .foregroundColor: UIColor(white: 0.3, alpha: 1)
      ]
    )
  }
}


extension TextChatViewController: MessagesDisplayDelegate {
  
  func backgroundColor(for message: MessageType, at indexPath: IndexPath,
                       in messagesCollectionView: MessagesCollectionView) -> UIColor {
    // 1
    return isFromCurrentSender(message: message) ? .blue : .gray
  }
  
  func shouldDisplayHeader(for message: MessageType, at indexPath: IndexPath,
                           in messagesCollectionView: MessagesCollectionView) -> Bool {
    // 2
    return true // you can use this method to display things like timestamp of a message
  }
  
  func messageStyle(for message: MessageType, at indexPath: IndexPath,
                    in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
    let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
    // 3
    return .bubbleTail(corner, .curved)
  }
}


// MARK: - MessagesLayoutDelegate

extension TextChatViewController: MessagesLayoutDelegate {
  
  func avatarSize(for message: MessageType, at indexPath: IndexPath,
                  in messagesCollectionView: MessagesCollectionView) -> CGSize {
    // 1
    return .zero // returning zero for the avatar will hide it from the view
  }
  
  func footerViewSize(for message: MessageType, at indexPath: IndexPath,
                      in messagesCollectionView: MessagesCollectionView) -> CGSize {
    // 2
    return CGSize(width: 0, height: 8) // add padding for better readability
  }
  
  func heightForLocation(message: MessageType, at indexPath: IndexPath,
                         with maxWidth: CGFloat, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
    // 3
    return 0 // probably won't need to use location messages so just make the height zero for now
  }
}


// MARK: - MessageInputBarDelegate

extension TextChatViewController: InputBarAccessoryViewDelegate {
  
  @objc(inputBar:didPressSendButtonWith:) func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
    // 1
    let message = Message(user: user, content: text)
    // 2
    save(message)
    // 3
    inputBar.inputTextView.text = ""
  }
  
  @objc(inputBar:didChangeIntrinsicContentTo:) func inputBar(_ inputBar: InputBarAccessoryView, didChangeIntrinsicContentTo size: CGSize) {
  }
  
  @objc(inputBar:textViewTextDidChangeTo:) func inputBar(_ inputBar: InputBarAccessoryView, textViewTextDidChangeTo text: String) {
  }
  
}

// MARK: - UIImagePickerControllerDelegate

extension TextChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
}

extension TextChatViewController: MessageLabelDelegate {
  
  func didSelectAddress(_ addressComponents: [String: String]) {
    print("Address Selected: \(addressComponents)")
  }
  
  func didSelectDate(_ date: Date) {
    print("Date Selected: \(date)")
  }
  
  func didSelectPhoneNumber(_ phoneNumber: String) {
    print("Phone Number Selected: \(phoneNumber)")
  }
  
  func didSelectURL(_ url: URL) {
    print("URL Selected: \(url)")
  }
  
  func didSelectTransitInformation(_ transitInformation: [String: String]) {
    print("TransitInformation Selected: \(transitInformation)")
  }
  
  func didSelectHashtag(_ hashtag: String) {
    print("Hashtag selected: \(hashtag)")
  }
  
  func didSelectMention(_ mention: String) {
    print("Mention selected: \(mention)")
  }
  
  func didSelectCustom(_ pattern: String, match: String?) {
    print("Custom data detector patter selected: \(pattern)")
  }
  
}
