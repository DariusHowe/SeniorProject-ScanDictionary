//
//  TakePhotoViewController.swift
//  ScanDictionary
//
//  Created by Matthew Shober on 3/26/19.
//  Copyright © 2019 Matthew Shober. All rights reserved.
//

import UIKit
import TesseractOCR
import GPUImage
import CoreMotion

class TakePhotoViewController: UIViewController {
    @IBOutlet weak var progessView: ProgressView!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    let defaultText = "Center your word over the box & tap to scan"
    @IBOutlet weak var helpText: UILabel!
    
    var pickerData: [String] = []
    
    @IBOutlet weak var textContainerView: UIView!
    
    var currentPickerIndex = 0
    @IBOutlet weak var pickerView: UIPickerView!
    
    @IBOutlet var cameraPreview: CameraPreview!
    
    let tesseract = G8Tesseract(language:"eng")!

    let camera = Camera()
    var scope: ScopeView!
    
    let webScrapper = WebScrapper.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        textContainerView.layer.cornerRadius = 10.0
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        tesseract.rect = self.cameraPreview.bounds
        tesseract.delegate = self
        tesseract.charWhitelist = "-_(){}[]=%.,?ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234567890/"
    }

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        print(#function)
            if camera.captureSession.isRunning == false {
                cameraPreview.setupPreview(for: camera.captureSession)
                camera.run()
            }
            
            scope = ScopeView(frame: CGRect(x: 0, y: 0, width: 250, height: 75))
            scope.center = cameraPreview.bounds.center
        
            self.scope.contentMode = .scaleAspectFit
            
            cameraPreview.addSubview(scope)
            
    }
    
    @IBAction func onTap(_ sender: UITapGestureRecognizer) {
        helpText.text = "Loading"
        camera.capture { (ci_image) in
            print(#function)
            
            guard var image = self.crop(ci_image, within: self.scope, previewSize: self.cameraPreview.frame.size) else {
                return
            }
            let luminanceThresholdFilter = GPUImageLuminanceThresholdFilter()
            luminanceThresholdFilter.threshold = 0.4
            image = luminanceThresholdFilter.image(byFilteringImage: image)!
            
            DispatchQueue.main.async {
                self.processImage(image)
            }
        }
    }
    
    private func crop(_ image: CIImage, within view: ScopeView, previewSize: CGSize) -> UIImage? {
        let imageViewScale = max(image.extent.width / previewSize.width,
                                 image.extent.height / previewSize.height)
        
        // Scale cropRect to handle images larger than shown-on-screen size
        let cropZone = CGRect(x: view.frame.origin.x * imageViewScale,
                              y: view.frame.origin.y * imageViewScale,
                              width: view.frame.size.width * imageViewScale,
                              height: view.frame.size.height * imageViewScale)
        
        let image = image.cropped(to: cropZone)
    
        guard let cgImage = CIContext().createCGImage(image, from:image.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
    
    
}

/* Tesseract Functions */
extension TakePhotoViewController: G8TesseractDelegate {
    func processImage(_ image: UIImage) {
//        let stillImageFilter = GPUImageAdaptiveThresholdFilter()
//        stillImageFilter.blurRadiusInPixels = 4.0
//        let Tesseractimage = stillImageFilter.image(byFilteringImage: image)!
//        let luminanceThresholdFilter = GPUImageLuminanceThresholdFilter()
//        luminanceThresholdFilter.threshold = 0.4
//        let image = luminanceThresholdFilter.image(byFilteringImage: image)!
        tesseract.image = image


        DispatchQueue.global(qos: .userInteractive).async {
            self.tesseract.recognize()
            var iteratorLevel = G8PageIteratorLevel.textline
            var blocks = self.tesseract.recognizedBlocks(by: iteratorLevel)
            
            iteratorLevel = G8PageIteratorLevel.word
            blocks = self.tesseract.recognizedBlocks(by: iteratorLevel)

            var closestWord: (String, CGFloat)?
            
            if let blocks = blocks as? [G8RecognizedBlock] {
                let center = CGRect(origin: CGPoint(x: 0, y: 0), size: image.size).center
                for block in blocks {
                    let distance = center.distance(from: block.boundingBox(atImageOf: image.size).center)
                    if closestWord == nil {
                        closestWord = (block.text, distance)
                    } else if closestWord!.1 > distance {
                        closestWord = (block.text, distance)
                    }
                }
            }
            
            DispatchQueue.main.async {
                if let closestWord = closestWord?.0 {
                    let word = self.removeSpecialCharsFromString(text: closestWord)
                    guard !self.pickerData.contains(word) else { return }

                    self.pickerData.insert(word, at: 0)
                }
                
//                if !self.pickerData.contains(closestWord!.0) {
////                    add
//                }
                self.pickerView.reloadAllComponents()
//                self.progessView.setProgress(progress: self.tesseract.progress)
                self.helpText.text = self.defaultText
                self.progessView.setProgress(progress: 0)

            }
        
//            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(5), execute: {
//                self.helpText.text = "Done"
//                self.progessView.setProgress(progress: 0)
//            })
        }
    }
    
    func removeSpecialCharsFromString(text: String) -> String {
        let okayChars : Set<Character> =
            Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890")
        return String(text.filter {okayChars.contains($0) })
    }
    
    func progressImageRecognition(for tesseract: G8Tesseract) {
        DispatchQueue.main.async {
            self.progessView.setProgress(progress: tesseract.progress)
        }
    }
    
    func shouldCancelImageRecognitionForTesseract(tesseract: G8Tesseract!) -> Bool {
        return false // return true if you need to interrupt tesseract before it finishes
    }
}

/* Functions specific to searching for words */
extension TakePhotoViewController {
    @IBAction func search(_ sender: Any) {
        guard !pickerData.isEmpty else { return }
        
        toggleActivityIndicator()
        let word = pickerData[currentPickerIndex]
        search(for: word)
    }
    
    func toggleActivityIndicator() {
        DispatchQueue.main.async {
            if self.activityIndicator.isAnimating {
                self.activityIndicator.stopAnimating()
            } else {
                self.activityIndicator.startAnimating()
            }
        }
    }
    private func search(for word: String) {
        print(#function, "for", word)

        webScrapper.getDefinition(for: word) { (result) in
            guard let word = result as? Word else {
                self.searchHelper(result)
                self.toggleActivityIndicator()
                return
            }
            let storyboard = UIStoryboard(name: "Main", bundle: nil)

            
            let tabBar = storyboard.instantiateViewController(withIdentifier: "tabbar") as! TabBarViewController
            
            tabBar.word = word
            DefinitionStorage.store(word)
            DispatchQueue.main.async {
                self.toggleActivityIndicator()
                self.navigationController?.pushViewController(tabBar, animated: true)
            }
        }
    }
    
    /* Handles misspelled words and no results */
    private func searchHelper(_ result: Any?) {
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


extension CGPoint {
    func distance(from point: CGPoint) -> CGFloat {
        let xDist = x - point.x
        let yDist = y - point.y
        return CGFloat(sqrt(xDist * xDist + yDist * yDist))
    }
}
