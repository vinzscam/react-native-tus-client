import { NativeModules, NativeEventEmitter } from 'react-native';
const { RNTusClient } = NativeModules;
const tusEventEmitter = new NativeEventEmitter(RNTusClient);
const defaultOptions = {
    headers: {},
    metadata: {}
};
/** Class representing a tus upload */
class Upload {
    /**
     *
     * @param file The file absolute path.
     * @param settings The options argument used to setup your tus upload.
     */
    constructor(file, options) {
        this.subscriptions = [];
        this.file = file;
        this.options = Object.assign({}, defaultOptions, options);
    }
    /**
     * Start or resume the upload using the specified file.
     * If no file property is available the error handler will be called.
     */
    start() {
        if (!this.file) {
            this.emitError(new Error('tus: no file or stream to upload provided'));
            return;
        }
        if (!this.options.endpoint) {
            this.emitError(new Error('tus: no endpoint provided'));
            return;
        }
        (this.uploadId
            ? Promise.resolve()
            : this.createUpload())
            .then(() => this.resume())
            .catch(e => this.emitError(e));
    }
    /**
     * Abort the currently running upload request and don't continue.
     * You can resume the upload by calling the start method again.
     */
    abort() {
        if (this.uploadId) {
            RNTusClient.abort(this.uploadId, (err) => {
                if (err) {
                    this.emitError(err);
                }
            });
        }
    }
    resume() {
        RNTusClient.resume(this.uploadId, (hasBeenResumed) => {
            if (!hasBeenResumed) {
                this.emitError(new Error('Error while resuming the upload'));
            }
        });
    }
    emitError(error) {
        if (this.options.onError) {
            this.options.onError(error);
        }
        else {
            throw error;
        }
    }
    createUpload() {
        return new Promise((resolve, reject) => {
            const { metadata, headers, endpoint } = this.options;
            const settings = { metadata, headers, endpoint };
            RNTusClient.createUpload(this.file, settings, (uploadId, errorMessage) => {
                this.uploadId = uploadId;
                if (uploadId == null) {
                    const error = errorMessage
                        ? new Error(errorMessage)
                        : null;
                    reject(error);
                }
                else {
                    this.subscribe();
                    resolve();
                }
            });
        });
    }
    subscribe() {
        this.subscriptions.push(tusEventEmitter.addListener('onSuccess', payload => {
            if (payload.uploadId === this.uploadId) {
                this.url = payload.uploadUrl;
                this.onSuccess();
                this.unsubscribe();
            }
        }));
        this.subscriptions.push(tusEventEmitter.addListener('onError', payload => {
            if (payload.uploadId === this.uploadId) {
                this.onError(payload.error);
            }
        }));
        this.subscriptions.push(tusEventEmitter.addListener('onProgress', payload => {
            if (payload.uploadId === this.uploadId) {
                this.onProgress(payload.bytesWritten, payload.bytesTotal);
            }
        }));
    }
    unsubscribe() {
        this.subscriptions.forEach(subscription => subscription.remove());
    }
    onSuccess() {
        this.options.onSuccess && this.options.onSuccess();
    }
    onProgress(bytesUploaded, bytesTotal) {
        this.options.onProgress
            && this.options.onProgress(bytesUploaded, bytesTotal);
    }
    onError(error) {
        this.options.onError && this.options.onError(error);
    }
}
export { Upload };
//# sourceMappingURL=index.js.map