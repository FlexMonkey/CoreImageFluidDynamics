//
//  ViewController.swift
//  CoreImageFluidDynamics
//
//  Created by Simon Gladman on 16/01/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

import UIKit
import GLKit

class ViewController: UIViewController {
    
    let rect640x640 = CGRect(x: 0, y: 0, width: 640, height: 640)
    
    let velocityAccumulator = CIImageAccumulator(extent: CGRect(x: 0, y: 0, width: 640, height: 640), format: kCIFormatARGB8)
    let pressureAccumulator = CIImageAccumulator(extent: CGRect(x: 0, y: 0, width: 640, height: 640), format: kCIFormatARGB8)
    
    let advectionFilter = AdvectionFilter()
    let divergenceFilter = DivergenceFilter()
    let jacobiFilter  = JacobiFilter()
    let subtractPressureGradientFilter = SubtractPressureGradientFilter()

    lazy var imageView: GLKView =
    {
        [unowned self] in
        
        let imageView = GLKView()
        
        imageView.layer.borderColor = UIColor.grayColor().CGColor
        imageView.layer.borderWidth = 1
        imageView.layer.shadowOffset = CGSize(width: 0, height: 0)
        imageView.layer.shadowOpacity = 0.75
        imageView.layer.shadowRadius = 5
        
        imageView.context = self.eaglContext
        imageView.delegate = self
        
        return imageView
        }()
    
    let eaglContext = EAGLContext(API: .OpenGLES2)
    
    lazy var ciContext: CIContext =
    {
        [unowned self] in
        
        return CIContext(EAGLContext: self.eaglContext,
            options: [kCIContextWorkingColorSpace: NSNull()])
        }()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.addSubview(imageView)
        
        setInitialImage()
        
        let displayLink = CADisplayLink(target: self, selector: Selector("step"))
        displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }
    
    func setInitialImage()
    {
        let black = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.0))
    
        velocityAccumulator.setImage(black)
    }
    
    func step()
    {
        imageView.setNeedsDisplay()
    }
    
    override func viewDidLayoutSubviews()
    {
        imageView.frame = CGRect(origin: CGPoint(x: view.frame.width / 2 - rect640x640.width / 2, y: view.frame.height / 2 - rect640x640.height / 2),
            size: CGSize(width: rect640x640.width, height: rect640x640.height))
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        if let touch = touches.first
        {
            let locationInView = CGPoint(x: touch.locationInView(imageView).x,
                y: 640 - touch.locationInView(imageView).y)
            
            let previousLocationInView = CGPoint(x: touch.previousLocationInView(imageView).x,
                y: 640 - touch.previousLocationInView(imageView).y)
            
            let pressureImage = CIImage(color: CIColor(red: 1, green: 0, blue: 0))
                .imageByCroppingToRect(CGRect(origin: locationInView.offset(30), size: CGSize(width: 60, height: 60)))
                .imageByApplyingFilter("CIGaussianBlur", withInputParameters: [kCIInputRadiusKey: 15])
            
            let directionX = ((max(min(locationInView.x - previousLocationInView.x, 5), -5)) / 10) + 0.5
            let directionY = ((max(min(locationInView.y - previousLocationInView.y, 5), -5)) / 10) + 0.5
            
            let directionimage = CIImage(color: CIColor(red: directionX, green: directionY, blue: 0))
                .imageByCroppingToRect(CGRect(origin: locationInView.offset(20), size: CGSize(width: 40, height: 40)))
                .imageByApplyingFilter("CIGaussianBlur", withInputParameters: [kCIInputRadiusKey: 5])
            
            velocityAccumulator.setImage(directionimage.imageByCompositingOverImage(velocityAccumulator.image()))
            
            pressureAccumulator.setImage(pressureImage.imageByCompositingOverImage(pressureAccumulator.image()))
        }
    }
    
}

extension CGPoint
{
    func offset(delta: CGFloat) -> CGPoint
    {
        return CGPoint(x: self.x - delta, y: self.y - delta)
    }
}

// MARK: GLKViewDelegate extension

extension ViewController: GLKViewDelegate
{
    func glkView(view: GLKView, drawInRect rect: CGRect)
    {
        advectionFilter.inputVelocity = velocityAccumulator.image()
        
        divergenceFilter.inputVelocity = advectionFilter.outputImage!
        let divergence = divergenceFilter.outputImage!
        
        for _ in 0 ... 2
        {
            jacobiFilter.inputDivergence = divergence
            jacobiFilter.inputPressure = pressureAccumulator.image()
            
            pressureAccumulator.setImage(jacobiFilter.outputImage)
        }
        
        subtractPressureGradientFilter.inputPressure = pressureAccumulator.image()
        subtractPressureGradientFilter.inputVelocity = advectionFilter.outputImage
        
        velocityAccumulator.setImage(subtractPressureGradientFilter.outputImage!)
        
        let finalImage = pressureAccumulator.image()
            .imageByApplyingFilter("CIMaximumComponent", withInputParameters: nil)
   
        ciContext.drawImage(finalImage,
            inRect: CGRect(x: 0, y: 0,
                width: imageView.drawableWidth,
                height: imageView.drawableHeight),
            fromRect: rect640x640)
    }
}

