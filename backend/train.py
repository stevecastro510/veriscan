"""Entrena el modelo. Dataset esperado:
data/original/*.jpg   data/replica/*.jpg
Uso: python train.py
"""
import os

import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import datasets

from app.ml import VeriScanNet, prep

ds = datasets.ImageFolder("data", transform=prep)  # clases alfabéticas: original=0, replica=1
dl = DataLoader(ds, batch_size=16, shuffle=True)
net = VeriScanNet()
opt = torch.optim.Adam(net.parameters(), 1e-4)
loss_fn = nn.BCELoss()

for ep in range(10):
    for x, y in dl:
        loss = loss_fn(net(x), (1 - y).float().unsqueeze(1))  # 1 = original
        opt.zero_grad(); loss.backward(); opt.step()
    print(f"epoch {ep} loss {loss.item():.4f}")

os.makedirs("models", exist_ok=True)
torch.save(net.state_dict(), "models/veriscan.pt")
