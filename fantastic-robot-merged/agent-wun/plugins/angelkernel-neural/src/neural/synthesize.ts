import { IntentClassifier } from './engine.js';
import { AdaptiveRouter } from './router.js';
import { CoherenceModel } from './coherence.js';
import { IntentCategory, IntentResult } from '../types/index.js';

export class NeuralEngine {
  public classifier: IntentClassifier;
  public router: AdaptiveRouter;
  public coherence: CoherenceModel;

  constructor(private neuralDir: string) {
    this.classifier = new IntentClassifier(neuralDir);
    this.router = new AdaptiveRouter(neuralDir);
    this.coherence = new CoherenceModel(neuralDir);
  }

  async initialize(): Promise<void> {
    await this.coherence.initialize();
  }

  async synthesize(query: string): Promise<IntentResult> {
    const intentResult = await this.classifier.classify(query);
    await this.router.route(query, intentResult);
    await this.coherence.updateIntentContext(intentResult.intent, query);
    return intentResult;
  }

  async classify(query: string): Promise<IntentResult> {
    return this.classifier.classify(query);
  }

  async coherenceCheck() {
    return this.coherence.checkCoherence();
  }
}
