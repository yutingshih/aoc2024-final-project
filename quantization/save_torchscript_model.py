from neural_compressor.utils.pytorch import load
from torchvision import transforms
from datasets import load_from_disk
from torch.utils.data import DataLoader
from datasets import Dataset, Features, Array3D
from transformers import AutoProcessor
import torch
import torchvision.models as models

# Step 2: Define the transform for the test data
transform_test = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

# Step 3: Apply the transform to the dataset
class CustomDataset(torch.utils.data.Dataset):
    def __init__(self, dataset, transform=None):
        self.dataset = dataset
        self.transform = transform

    def __len__(self):
        return len(self.dataset)

    def __getitem__(self, idx):
        sample = self.dataset[idx]
        image = sample['image']  # Assuming the dataset has 'image' key for images
        label = sample['label']  # Assuming the dataset has 'label' key for labels

        if self.transform:
            image = self.transform(image)

        return image, label
    
# Function to process dataset examples
def process_examples(examples, image_processor):
    images = [img.convert('RGB') if img.mode != "RGB" else img for img in examples['image']]
    inputs = image_processor(images=images)
    examples['pixel_values'] = inputs['pixel_values']
    return examples

# Apply processing to the test dataset
def apply_processing(
    model_name: str,
    test_dataset: Dataset,
) -> Dataset:
    features = Features({
        **test_dataset.features,
        'pixel_values': Array3D(dtype="float32", shape=(3, 224, 224)),
    })

    image_processor = AutoProcessor.from_pretrained(model_name)
    test_dataset = test_dataset.map(process_examples, batch_size=500, batched=True, features=features, fn_kwargs={"image_processor": image_processor})
    test_dataset.set_format('torch', columns=['pixel_values', 'label'])
    test_dataset = test_dataset.remove_columns("image")
    
    return test_dataset

# Load the test dataset from disk
test_dataset = load_from_disk('./data/test_dataset')
subset_test_dataset = test_dataset.select(range(1000))  # Select a subset of the test dataset

print(subset_test_dataset)
model_name = "facebook/deit-small-patch16-224"
test_dataset = apply_processing(model_name, subset_test_dataset)  # Apply processing to the test dataset
batch_size = 32
test_dataloader = DataLoader(test_dataset, num_workers=32, batch_size=batch_size)  # Create a DataLoader for the test dataset

# Load the pre-trained model
model_names = models.list_models(module=models)
arch = 'squeezenet1_0'
print("=> using pre-trained model '{}'".format(arch))
model = models.__dict__[arch](pretrained=False)

# Load the quantized model
path = '/workspace/quant/neural-compressor/examples/pytorch/image_recognition/torchvision_models/quantization/ptq/cpu/fx/saved_results'
test_dataloader = DataLoader(test_dataset, num_workers=32, batch_size=batch_size)  # Create a DataLoader for the test dataset
quantized_model = load(path, model, dataloader=test_dataloader)

# Print the state dictionary of the quantized model
quantized_model.state_dict()

# Save the quantized model using TorchScript
scripted_model = torch.jit.script(quantized_model)
scripted_model_name = f"quantized_{arch}_v1.pt"
scripted_model.save(scripted_model_name)

# Load the quantized model using TorchScript
loaded_scripted_model = torch.jit.load(scripted_model_name)
loaded_scripted_model.eval()  # Set the model to evaluation mode
loaded_scripted_model.state_dict()

# Perform inference with both the original and loaded models
input_tensor = torch.randn(1, 3, 224, 224)
original_output = quantized_model(input_tensor)
loaded_output = loaded_scripted_model(input_tensor)
print("Original Output:", original_output)
print("Loaded Output:", loaded_output)
print("Difference:", torch.sum(torch.abs(original_output - loaded_output)))
