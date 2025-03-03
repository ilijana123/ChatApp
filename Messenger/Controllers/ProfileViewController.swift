import UIKit
import FirebaseAuth
import SDWebImage

final class ProfileViewController: UIViewController {

    @IBOutlet var tableView: UITableView!

    var data = [ProfileViewModel]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadUserData), name: NSNotification.Name("didLogInNotification"), object: nil)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableHeader()

        loadUserData()
    }

    private let activitySwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = false
        toggle.addTarget(self, action: #selector(didToggleActivityStatus), for: .valueChanged)
        return toggle
    }()

    /// Fetch the logged-in user's data
    @objc private func loadUserData() {
        guard let email = FirebaseAuth.Auth.auth().currentUser?.email else {
            print("No logged-in user found")
            return
        }

        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        DatabaseManager.shared.getDataFor(path: safeEmail) { [weak self] result in
            switch result {
            case .success(let data):
                guard let userData = data as? [String: Any],
                      let firstName = userData["first_name"] as? String,
                      let lastName = userData["last_name"] as? String else {
                    return
                }

                let fullName = "\(firstName) \(lastName)"
                UserDefaults.standard.set(fullName, forKey: "name")
                UserDefaults.standard.set(email, forKey: "email")

                DispatchQueue.main.async {
                    self?.updateProfileView()
                }
                
            case .failure(let error):
                print("Failed to fetch user data: \(error)")
            }
        }
        DatabaseManager.shared.getUserActivityStatus(email: email) { [weak self] isActive in
            DispatchQueue.main.async {
                self?.activitySwitch.isOn = isActive ?? false
            }
        }
    }

    /// Update the profile UI with the latest user data
    private func updateProfileView() {
        data = []
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: "Name: \(UserDefaults.standard.value(forKey: "name") as? String ?? "No Name")",
                                     handler: nil))
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String ?? "No Email")",
                                     handler: nil))
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: "Active Status",
                                     handler: nil))
        data.append(ProfileViewModel(viewModelType: .logout, title: "Log Out", handler: { [weak self] in
            self?.handleLogout()
        }))
        
        tableView.reloadData()
        tableView.tableHeaderView = createTableHeader() // Reload header view
    }

    /// Create profile header with profile picture
    func createTableHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }

        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let filename = safeEmail + "_profile_picture.png"
        let path = "images/" + filename

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.width, height: 300))
        headerView.backgroundColor = .link

        let imageView = UIImageView(frame: CGRect(x: (headerView.width-150) / 2, y: 75, width: 150, height: 150))
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .white
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width / 2
        headerView.addSubview(imageView)

        // Load the profile picture from Firebase
        StorageManager.shared.downloadURL(for: path) { result in
            switch result {
            case .success(let url):
                DispatchQueue.main.async {
                    imageView.sd_setImage(with: url, completed: nil)
                }
            case .failure(let error):
                print("Failed to get download url: \(error)")
            }
        }

        return headerView
    }

    /// Handle user logout
    private func handleLogout() {
        let actionSheet = UIAlertController(title: "Log Out",
                                            message: "Are you sure you want to log out?",
                                            preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: "Log Out", style: .destructive, handler: { [weak self] _ in
            guard let strongSelf = self else { return }

            // Clear UserDefaults
            UserDefaults.standard.removeObject(forKey: "email")
            UserDefaults.standard.removeObject(forKey: "name")
            UserDefaults.standard.synchronize()

            do {
                try FirebaseAuth.Auth.auth().signOut()

                DispatchQueue.main.async {
                    // Redirect to login screen
                    let loginVC = LoginViewController()
                    let navVC = UINavigationController(rootViewController: loginVC)
                    navVC.modalPresentationStyle = .fullScreen
                    strongSelf.present(navVC, animated: true)
                }

            } catch let signOutError {
                print("❌ Failed to log out: \(signOutError.localizedDescription)")
            }
        }))

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(actionSheet, animated: true)
    }
}

// MARK: - TableView Delegate and DataSource

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier,
                                                 for: indexPath) as! ProfileTableViewCell
        cell.setUp(with: viewModel)
        if indexPath.row == 2 {
            cell.accessoryView = activitySwitch
        }
        return cell
    }
    @objc private func didToggleActivityStatus(_ sender: UISwitch) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return }
        let isActive = sender.isOn

        DatabaseManager.shared.updateUserActivityStatus(email: email, isActive: isActive) { success in
            if success {
                print("✅ Updated activity status to: \(isActive)")
            } else {
                print("❌ Failed to update activity status")
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        data[indexPath.row].handler?()
    }
}

// MARK: - ProfileTableViewCell

class ProfileTableViewCell: UITableViewCell {
    static let identifier = "ProfileTableViewCell"

    public func setUp(with viewModel: ProfileViewModel) {
        self.textLabel?.text = viewModel.title
        switch viewModel.viewModelType {
        case .info:
            textLabel?.textAlignment = .left
            selectionStyle = .none
        case .logout:
            textLabel?.textColor = .red
            textLabel?.textAlignment = .center
        }
    }
}

