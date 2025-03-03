//
//  ConversationTableViewCell.swift
//  Messenger

import UIKit
import SDWebImage

class ConversationTableViewCell: UITableViewCell {

    static let identifier = "ConversationTableViewCell"

    private let userImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 50
        imageView.layer.masksToBounds = true
        return imageView
    }()

    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        return label
    }()

    private let userMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 19, weight: .regular)
        label.numberOfLines = 2
        return label
    }()
    
    private let dateLabel: UILabel = {
            let label = UILabel()
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textColor = .lightGray
            label.textAlignment = .right
            return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNameLabel)
        contentView.addSubview(userMessageLabel)
        contentView.addSubview(dateLabel)
        
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let padding: CGFloat = 10
        let imageSize: CGFloat = 60

        userImageView.frame = CGRect(x: padding,
                                     y: padding,
                                     width: imageSize,
                                     height: imageSize)

        userNameLabel.frame = CGRect(x: userImageView.right + padding,
                                     y: padding,
                                     width: contentView.width - userImageView.right - (padding * 2),
                                     height: 25)

        userMessageLabel.frame = CGRect(x: userImageView.right + padding,
                                        y: userNameLabel.bottom + 5,
                                        width: contentView.width - userImageView.right - (padding * 2),
                                        height: 40)

        dateLabel.frame = CGRect(x: userImageView.right + padding,
                                 y: userMessageLabel.bottom + 5,  // Move below message
                                 width: contentView.width - userImageView.right - (padding * 2),
                                 height: 18)
    }
    
    public func configure(with model: Conversation) {
            userMessageLabel.text = model.latestMessage.text
            userNameLabel.text = model.name

            let formattedDate = formatDateString(model.latestMessage.date)
            dateLabel.text = formattedDate

            let path = "images/\(model.otherUserEmail)_profile_picture.png"
            StorageManager.shared.downloadURL(for: path) { [weak self] result in
                switch result {
                case .success(let url):
                    DispatchQueue.main.async {
                        self?.userImageView.sd_setImage(with: url, completed: nil)
                    }
                case .failure(let error):
                    print("Failed to get image URL: \(error)")
                }
            }
        }

        private func formatDateString(_ dateString: String) -> String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, yyyy 'at' h:mm:ss a zzz"
            dateFormatter.timeZone = TimeZone(abbreviation: "PST")
            
            if let date = dateFormatter.date(from: dateString) {
                let outputFormatter = DateFormatter()
                outputFormatter.dateFormat = "MMM d, h:mm a"
                return outputFormatter.string(from: date)
            } else {
                return "N/A"
            }
        }}
