class VirtualBackground {
    static instance = null;

    constructor() {
        // Ensure only one instance of VirtualBackground exists
        if (VirtualBackground.instance) {
            return VirtualBackground.instance;
        }
        VirtualBackground.instance = this;

        this.resetState();
    }

    resetState() {
        // Reset all necessary state variables
        this.segmentation = null;
        this.initialized = false;
        this.pendingFrames = [];
        this.activeProcessor = null;
        this.activeGenerator = null;
        this.isProcessing = false;
        this.gifAnimation = null;
        this.gifCanvas = null;
        this.frameCounter = 0;
        this.lastSegmentationMask = null;
    }

    async initializeSegmentation() {
        // Initialize the segmentation model if not already done
        if (this.initialized) return;

        try {
            this.segmentation = new SelfieSegmentation({
                locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/selfie_segmentation/${file}`,
            });

            this.segmentation.setOptions({
                modelSelection: 1, // Higher accuracy
                runningMode: 'video', // Smoother segmentation for streaming
                smoothSegmentation: true, // Enables smoother edges
            });

            this.segmentation.onResults(this.handleSegmentationResults.bind(this));

            await this.segmentation.initialize();
            this.initialized = true;
            console.log('✅ Segmentation initialized successfully.');
        } catch (error) {
            console.error('❌ Error initializing segmentation:', error);
            throw error;
        }
    }

    handleSegmentationResults(results) {
        if (!results?.segmentationMask) return;

        this.lastSegmentationMask = results.segmentationMask; // Store mask for skipped frames

        const pending = this.pendingFrames.shift();
        if (!pending || !pending.shouldProcess) return;

        const { videoFrame, controller, imageBitmap, maskHandler } = pending;
        this.processFrame(videoFrame, controller, imageBitmap, maskHandler, results.segmentationMask);
    }

    processFrame(videoFrame, controller, imageBitmap, maskHandler, segmentationMask) {
        try {
            const canvas = new OffscreenCanvas(videoFrame.displayWidth, videoFrame.displayHeight);
            const ctx = canvas.getContext('2d');

            // Apply original frame
            ctx.drawImage(imageBitmap, 0, 0, canvas.width, canvas.height);

            // Apply mask processing
            maskHandler(ctx, canvas, segmentationMask, imageBitmap);

            // Create new video frame with the processed content
            const processedFrame = new VideoFrame(canvas, {
                timestamp: videoFrame.timestamp,
                alpha: 'keep',
            });

            // Enqueue the processed frame to continue the stream
            controller.enqueue(processedFrame);
        } catch (error) {
            console.error('❌ Frame processing error:', error);
        } finally {
            // Close frames after processing to release resources
            this.closeFrames(videoFrame, imageBitmap);
        }
    }

    closeFrames(videoFrame, imageBitmap) {
        if (videoFrame && !videoFrame.closed) {
            videoFrame.close();
        }
        if (imageBitmap && !imageBitmap.closed) {
            imageBitmap.close();
        }
    }

    async processStreamWithSegmentation(videoTrack, maskHandler) {
        // Initialize segmentation if not already done
        await this.initializeSegmentation();

        // Create new processor and generator for stream transformation
        const processor = new MediaStreamTrackProcessor({ track: videoTrack });
        const generator = new MediaStreamTrackGenerator({ kind: 'video' });

        const transformer = new TransformStream({
            transform: async (videoFrame, controller) => {
                if (!this.segmentation || !this.initialized) {
                    console.warn('⚠️ Segmentation is not initialized, skipping frame.');
                    this.closeFrames(videoFrame);
                    return;
                }

                try {
                    // Create image bitmap from video frame
                    const imageBitmap = await createImageBitmap(videoFrame);

                    if (!imageBitmap) {
                        console.warn('⚠️ Failed to create imageBitmap, skipping frame.');
                        this.closeFrames(videoFrame);
                        return;
                    }

                    if (this.frameCounter % 3 === 0) {
                        // Process only every 3rd frame
                        this.pendingFrames.push({
                            videoFrame,
                            controller,
                            imageBitmap,
                            maskHandler,
                            shouldProcess: true, // Mark frame for processing
                        });

                        // Send the image to the segmentation model
                        await this.segmentation.send({ image: imageBitmap });
                    } else {
                        // Use last segmentation mask for skipped frames
                        if (this.lastSegmentationMask) {
                            this.processFrame(
                                videoFrame,
                                controller,
                                imageBitmap,
                                maskHandler,
                                this.lastSegmentationMask,
                            );
                        } else {
                            // If no previous mask, just enqueue the original frame
                            controller.enqueue(videoFrame);
                        }
                    }

                    this.frameCounter++; // Increment frame counter
                } catch (error) {
                    console.error('❌ Frame transformation error:', error);
                } finally {
                    // Close the video frame after processing
                    this.closeFrames(videoFrame);
                }
            },
            flush: () => this.cleanPendingFrames(), // Clean up any pending frames when the stream ends
        });

        // Store active streams
        this.activeProcessor = processor;
        this.activeGenerator = generator;
        this.isProcessing = true;

        // Start the processing pipeline
        processor.readable
            .pipeThrough(transformer)
            .pipeTo(generator.writable)
            .catch(() => this.stopCurrentProcessor());

        return new MediaStream([generator]);
    }

    cleanPendingFrames() {
        // Close all pending frames to release resources
        while (this.pendingFrames.length) {
            const { videoFrame, imageBitmap } = this.pendingFrames.pop();
            this.closeFrames(videoFrame, imageBitmap);
        }
    }

    async stopCurrentProcessor() {
        // Stop any ongoing processor and clean up resources
        if (!this.activeProcessor) return;

        this.isProcessing = false;
        this.cleanPendingFrames();

        try {
            // Abort the writable stream if it's not locked
            if (this.activeGenerator?.writable && !this.activeGenerator.writable.locked) {
                await this.activeGenerator.writable.abort('Processing stopped');
            }

            // Cancel the readable stream if it's not locked
            if (this.activeProcessor?.readable && !this.activeProcessor.readable.locked) {
                await this.activeProcessor.readable.cancel('Processing stopped');
            }

            console.log('✅ Processor successfully stopped');
        } catch (error) {
            console.error('❌ Processor shutdown error:', error);
        } finally {
            // Reset active processor and generator
            this.activeProcessor = null;
            this.activeGenerator = null;
        }
    }

    async applyBlurToWebRTCStream(videoTrack, blurLevel = 10) {
        // Handler for applying blur effect to the background
        const maskHandler = (ctx, canvas, mask, imageBitmap) => {
            // Keep only the person using the segmentation mask
            ctx.save();
            ctx.globalCompositeOperation = 'destination-in';
            ctx.drawImage(mask, 0, 0, canvas.width, canvas.height);
            ctx.restore();

            // Apply blur to background and draw image behind the person
            ctx.save();
            ctx.globalCompositeOperation = 'destination-over';
            ctx.filter = `blur(${blurLevel}px)`;
            ctx.drawImage(imageBitmap, 0, 0, canvas.width, canvas.height);
            ctx.restore();
        };

        console.log('✅ Apply Blur.');
        return this.processStreamWithSegmentation(videoTrack, maskHandler);
    }

    async applyVirtualBackgroundToWebRTCStream(videoTrack, imageUrl) {
        // Determine if the background is a GIF
        const isGif = imageUrl.endsWith('.gif') || imageUrl.startsWith('data:image/gif');
        const background = isGif ? await this.loadGifImage(imageUrl) : await this.loadImage(imageUrl);

        // Handler for applying virtual background
        const maskHandler = (ctx, canvas, mask, imageBitmap) => {
            // Create an offscreen canvas for a softer mask
            const maskCanvas = new OffscreenCanvas(canvas.width, canvas.height);
            const maskCtx = maskCanvas.getContext('2d');

            // Apply slight blur to mask to smooth edges
            maskCtx.filter = 'blur(5px)'; // Adjust to control softness
            maskCtx.drawImage(mask, 0, 0, canvas.width, canvas.height);

            // Apply the softened mask
            ctx.globalCompositeOperation = 'destination-in';
            ctx.drawImage(maskCanvas, 0, 0, canvas.width, canvas.height);

            // Draw background behind the person
            ctx.globalCompositeOperation = 'destination-over';
            ctx.drawImage(background, 0, 0, canvas.width, canvas.height);
        };

        console.log('✅ Apply Virtual Background.');
        return this.processStreamWithSegmentation(videoTrack, maskHandler);
    }

    async loadImage(src) {
        // Load an image from the provided source URL
        return new Promise((resolve, reject) => {
            const img = new Image();
            img.crossOrigin = 'anonymous';
            img.src = src;
            img.onload = () => resolve(img);
            img.onerror = reject;
        });
    }

    async loadGifImage(src) {
        // Load and animate a GIF using gifler
        return new Promise((resolve, reject) => {
            try {
                if (this.gifAnimation) {
                    this.gifAnimation.stop(); // Stop previous animation
                    this.gifAnimation = null;
                }

                if (!this.gifCanvas) {
                    this.gifCanvas = document.createElement('canvas');
                }

                gifler(src).get((animation) => {
                    this.gifAnimation = animation;
                    animation.animateInCanvas(this.gifCanvas); // Start the animation
                    console.log('✅ GIF loaded and animation started.');
                    resolve(this.gifCanvas);
                });
            } catch (error) {
                console.error('❌ Error loading GIF with gifler:', error);
                reject(error);
            }
        });
    }
}
