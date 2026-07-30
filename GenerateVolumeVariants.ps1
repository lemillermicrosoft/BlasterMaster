param(
  [string]$AudioDirectory = (Join-Path $PSScriptRoot "Media\Audio")
)

if (-not ("BlasterMasterWavVolumeV2" -as [type])) {
  Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Text;

public static class BlasterMasterWavVolumeV2
{
    public static void Generate(string sourcePath, string destinationPath, double gain)
    {
        byte[] audio = File.ReadAllBytes(sourcePath);
        if (audio.Length < 44 || Encoding.ASCII.GetString(audio, 0, 4) != "RIFF" ||
            Encoding.ASCII.GetString(audio, 8, 4) != "WAVE")
            throw new InvalidDataException(sourcePath + " is not a RIFF/WAVE file.");

        int chunkOffset = 12;
        int dataOffset = -1;
        int dataLength = 0;
        while (chunkOffset + 8 <= audio.Length)
        {
            string chunkName = Encoding.ASCII.GetString(audio, chunkOffset, 4);
            int chunkLength = BitConverter.ToInt32(audio, chunkOffset + 4);
            if (chunkName == "fmt ")
            {
                if (BitConverter.ToInt16(audio, chunkOffset + 8) != 1 ||
                    BitConverter.ToInt16(audio, chunkOffset + 22) != 16)
                    throw new InvalidDataException(sourcePath + " must be 16-bit PCM.");
            }
            else if (chunkName == "data")
            {
                dataOffset = chunkOffset + 8;
                dataLength = Math.Min(chunkLength, audio.Length - dataOffset);
                break;
            }
            chunkOffset += 8 + chunkLength + (chunkLength % 2);
        }

        if (dataOffset < 0) throw new InvalidDataException(sourcePath + " has no data chunk.");

        byte[] output = (byte[])audio.Clone();
        int dataEnd = dataOffset + dataLength;
        for (int offset = dataOffset; offset + 1 < dataEnd; offset += 2)
        {
            short sample = (short)(audio[offset] | (audio[offset + 1] << 8));
          double amplified = Math.Round(sample * gain);
          short scaled = (short)Math.Max(short.MinValue, Math.Min(short.MaxValue, amplified));
            output[offset] = (byte)(scaled & 0xff);
            output[offset + 1] = (byte)((scaled >> 8) & 0xff);
        }

        Directory.CreateDirectory(Path.GetDirectoryName(destinationPath));
        File.WriteAllBytes(destinationPath, output);
    }
}
"@
}

$volumeLevels = [ordered]@{
  25 = 0.25
  50 = 0.50
  75 = 0.75
  200 = 2.00
  300 = 3.00
}

$sourceFiles = Get-ChildItem $AudioDirectory -Filter "*.wav" -File
foreach ($volumeLevel in $volumeLevels.GetEnumerator()) {
  $destinationDirectory = Join-Path $AudioDirectory ("Volume\" + $volumeLevel.Key)
  foreach ($sourceFile in $sourceFiles) {
    $destinationPath = Join-Path $destinationDirectory $sourceFile.Name
    [BlasterMasterWavVolumeV2]::Generate($sourceFile.FullName, $destinationPath, $volumeLevel.Value)
  }
}

Write-Output ("Generated {0} volume variants." -f ($sourceFiles.Count * $volumeLevels.Count))