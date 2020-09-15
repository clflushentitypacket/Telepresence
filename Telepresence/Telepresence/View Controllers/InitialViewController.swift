import UIKit

class InitialViewController: UIViewController {
    
    @IBOutlet weak var callModeButton: UIButton!
    @IBOutlet weak var receiveModeButton: UIButton!
    @IBOutlet weak var testModeButton: UIButton!
    
    @IBAction func callModeButtonPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "callSegue", sender: self)
    }
    
    @IBAction func receiveModeButtonPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "receiveSegue", sender: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        callModeButton.backgroundColor = .clear
        callModeButton.layer.cornerRadius = 8
        callModeButton.layer.borderWidth = 1
        callModeButton.layer.borderColor = UIColor.black.cgColor
        callModeButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        
        
        receiveModeButton.backgroundColor = .clear
        receiveModeButton.layer.cornerRadius = 8
        receiveModeButton.layer.borderWidth = 1
        receiveModeButton.layer.borderColor = UIColor.black.cgColor
        receiveModeButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        
        
        testModeButton.backgroundColor = .clear
        testModeButton.layer.cornerRadius = 8
        testModeButton.layer.borderWidth = 1
        testModeButton.layer.borderColor = UIColor.black.cgColor
        testModeButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "callSegue" {
            let viewController = segue.destination as? CallViewController
            viewController?.user = .caller
            viewController?.title = "Call Mode"
        } else {
            let viewController = segue.destination as? CallViewController
            viewController?.user = .receiver
            viewController?.title = "Receive Mode"
        }
    }
}
