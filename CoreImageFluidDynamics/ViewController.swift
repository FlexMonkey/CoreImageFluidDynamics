//
//  ViewController.swift
//  CoreImageFluidDynamics
//
//  Created by Simon Gladman on 16/01/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//
//  Based on https://github.com/jwagner/fluidwebgl

import UIKit
import GLKit

let rect640x640 = CGRect(x: 0, y: 0, width: 640, height: 640)

class ViewController: UIViewController
{
    let velocityAccumulator = CIImageAccumulator(extent: rect640x640, format: kCIFormatARGB8)
    let pressureAccumulator = CIImageAccumulator(extent: rect640x640, format: kCIFormatARGB8)
    
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
        
        velocityAccumulator.setImage(CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.0)))
        
        let displayLink = CADisplayLink(target: self, selector: Selector("step"))
        displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }
    
    func step()
    {
        imageView.setNeedsDisplay()
    }
    
    override func viewDidLayoutSubviews()
    {
        imageView.frame = CGRect(origin: CGPoint(x: view.frame.midX - rect640x640.midX,
                y: view.frame.midY - rect640x640.midY),
            size: CGSize(width: rect640x640.width, height: rect640x640.height))
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let touch = touches.first else
        {
            return
        }

        let locationInView = CGPoint(
            x: touch.locationInView(imageView).x,
            y: 640 - touch.locationInView(imageView).y)

        let previousLocationInView = CGPoint(
            x: touch.previousLocationInView(imageView).x,
            y: 640 - touch.previousLocationInView(imageView).y)

        let red = CIColor(red: 1, green: 0, blue: 0)
                
        let pressureImage = CIImage(color: red)
            .imageByCroppingToRect(CGRect(
                origin: locationInView.offset(20),
                size: CGSize(width: 40, height: 40)))
            .imageByApplyingFilter("CIGaussianBlur",
                withInputParameters: [kCIInputRadiusKey: 10])

        let deltaX = locationInView.x - previousLocationInView.x
        let deltaY = locationInView.y - previousLocationInView.y
                
        let directionX = ((max(min(deltaX, 10), -10)) / 20) + 0.5
        let directionY = ((max(min(deltaY, 10), -10)) / 20) + 0.5

        let directionColor = CIColor(red: directionX, green: directionY, blue: 0)
                
        let directionImage = CIImage(color: directionColor)
            .imageByCroppingToRect(CGRect(
                origin: locationInView.offset(15),
                size: CGSize(width: 30, height: 30)))
            .imageByApplyingFilter("CIGaussianBlur",
                withInputParameters: [kCIInputRadiusKey: 5])

        velocityAccumulator.setImage(directionImage
            .imageByCompositingOverImage(velocityAccumulator.image()))

        pressureAccumulator.setImage(pressureImage
            .imageByCompositingOverImage(pressureAccumulator.image()))
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

        jacobiFilter.inputDivergence = divergenceFilter.outputImage!
        
        for _ in 0 ... 3
        {
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

