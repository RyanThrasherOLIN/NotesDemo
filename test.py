import torch
from transformers import AutoModel, AutoTokenizer
import numpy as np
import coremltools as ct

# Define a wrapper class for the AutoModel to return only the last_hidden_state
class ModelWrapper(torch.nn.Module):
    def __init__(self, model):
        super(ModelWrapper, self).__init__()
        self.model = model

    def forward(self, input_ids, attention_mask):
        # Extract the 'last_hidden_state' from the model output
        output = self.model(input_ids=input_ids, attention_mask=attention_mask)
        return output.last_hidden_state  # or use 'pooler_output' if needed

# Load your SentenceTransformer model and tokenizer
model_name = "mixedbread-ai/mxbai-embed-large-v1"  # Replace with your model
model = AutoModel.from_pretrained(model_name)
model.eval()
tokenizer = AutoTokenizer.from_pretrained(model_name)

# Wrap the model to return only the tensor output
wrapped_model = ModelWrapper(model)
wrapped_model.eval()

# Sample input to export the model
dummy_input = tokenizer("hello test this is a sample sentence that we might encode using our model.  How long would it take to do so?", return_tensors="pt")

# Trace the model using tensor inputs (input_ids, attention_mask)
traced_model = torch.jit.trace(wrapped_model, (dummy_input['input_ids'], dummy_input['attention_mask']))
# Convert the traced PyTorch model to CoreML using the ML Program format
model_from_torch = ct.convert(
    traced_model,
    inputs=[
        ct.TensorType(name="input_ids", shape=(1, ct.RangeDim(1, 512)), dtype=np.float32),
        ct.TensorType(name="attention_mask", shape=(1, ct.RangeDim(1, 512)), dtype=np.float32)
    ],
    minimum_deployment_target=ct.target.iOS17,
    convert_to="mlprogram",
    compute_precision=ct.precision.FLOAT16
)

# Save the CoreML model as an mlpackage
model_from_torch.save("mxbai-embed-large-v1.mlpackage")
