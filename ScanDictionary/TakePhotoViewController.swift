//
//  TakePhotoViewController.swift
//  ScanDictionary
//
//  Created by Matthew Shober on 3/26/19.
//  Copyright © 2019 Matthew Shober. All rights reserved.
//

import UIKit
import TesseractOCR

class TakePhotoViewController: UIViewController {
    
    var pickerData = ["Item1", "asdasdasd", "assdffdfgugyugnbuib", "work"]
    var currentPickerIndex = 0
    @IBOutlet weak var pickerView: UIPickerView!
    
    @IBOutlet var cameraPreview: CameraPreview!
    
    let tesseract = G8Tesseract(language:"eng")!

    let camera = Camera()
    var scope: ScopeView!
    
    var imageView: UIImageView!
    let webScrapper = WebScrapperHelper()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        tesseract.rect = self.cameraPreview.bounds
        tesseract.delegate = self
        tesseract.charWhitelist = "-_(){}[]=%.,?ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234567890/"
//
//        cameraPreview.addSubview(imageView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print(#function)
        if camera.captureSession.isRunning == false {
            cameraPreview.setupPreview(for: camera.captureSession)
            camera.run()
        }
       
        
        scope = ScopeView(frame: CGRect(x: 46.875, y: 212.5, width: 281.25, height: 75))
        
        imageView = UIImageView(frame: self.scope.bounds)

        self.imageView.contentMode = .scaleAspectFit
        self.scope.contentMode = .scaleAspectFit
        print("Camera Preview:", cameraPreview.frame)
        print("Scope View:", scope.frame)
        print("Image View:", imageView.frame)
        
        scope.addSubview(imageView)
        cameraPreview.addSubview(scope)

    }
    
    @IBAction func takePhoto(_ sender: Any) {
        camera.capture { (ci_image) in
            print(#function)

            guard let image = self.crop(ci_image, within: self.scope, previewSize: self.cameraPreview.frame.size) else {
                return
            }
            DispatchQueue.main.async {
                print(#function)

                self.imageView.image = image
//                Tesseract Process
            }
            
        }
        
    }
    
    func crop(_ image: CIImage, within view: ScopeView, previewSize: CGSize) -> UIImage? {
        let imageViewScale = max(image.extent.width / previewSize.width,
                                 image.extent.height / previewSize.height)
        
        // Scale cropRect to handle images larger than shown-on-screen size
        let cropZone = CGRect(x: view.frame.origin.x * imageViewScale,
                              y: view.frame.origin.y * imageViewScale,
                              width: view.frame.size.width * imageViewScale,
                              height: view.frame.size.height * imageViewScale)
        
        print("Image Size:", image.extent.size)
        print("Preview Size:", previewSize)
        print("CropZone:", cropZone)
        let image = image.cropped(to: cropZone)
    
        guard let cgImage = CIContext().createCGImage(image, from:image.extent) else {
            return nil
        }
        print(self.scope.frame.origin)
        print(self.imageView.frame.origin)

        return UIImage(cgImage: cgImage)
    }
}

extension TakePhotoViewController: G8TesseractDelegate {
    
}

/* Functions specific to searching for words */
extension TakePhotoViewController {
    @IBAction func search(_ sender: Any) {
        let word = pickerData[currentPickerIndex]
        search(for: word)
    }
    
    private func search(for word: String) {
        print(#function, "for", word)
        webScrapper.getDefinition(for: word) { (result) in
            print(result)
            guard let word = result as? Word else {
                self.searchHelper(result)
                return
            }
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let definitionController = storyboard.instantiateViewController(withIdentifier: "DefinitionViewController") as! DefinitionViewController
            
            definitionController.word = word
            DispatchQueue.main.async {
                print("PRESENTING")
                self.present(definitionController, animated: true, completion: nil)
            }
        }
    }
    
    /* Handles misspelled words and no results */
    private func searchHelper(_ result: Any?) {
        print(#function)
        print("**************")
        DispatchQueue.main.async {
            var title: String?
            var message: String?
            var alertController: UIAlertController!
            if let suggestion = result as! String? {
                title = "Misspelled Word"
                message = "Did you mean \(suggestion)"
                alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alertController.addAction(self.yesAction(for: suggestion))
                alertController.addAction(self.noAction())
            } else if result == nil {
                title = "No Result"
                alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alertController.addAction(self.retryAction())
            }
            
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    private func yesAction(for suggestion: String) -> UIAlertAction {
        return UIAlertAction(title: "Yes", style: .default, handler: { (result) in
            self.search(for: suggestion)
        })
    }
    
    private func noAction() -> UIAlertAction {
        return UIAlertAction(title: "No", style: .cancel, handler: { (result) in
            self.pickerData.remove(at: self.currentPickerIndex)
            self.pickerView.reloadAllComponents()
        })
    }
    
    private func retryAction() -> UIAlertAction {
        return UIAlertAction(title: "Retry", style: .default, handler: { (result) in
            self.pickerData.remove(at: self.currentPickerIndex)
            self.pickerView.reloadAllComponents()
        })
    }
}
extension TakePhotoViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    // The data to return fopr the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerData[row]
    }
    
    // Capture the picker view selection
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        currentPickerIndex = row
        // This method is triggered whenever the user makes a change to the picker selection.
    }
}
